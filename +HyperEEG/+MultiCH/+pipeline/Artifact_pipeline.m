function [outputFiles, excludedFiles] = ...
        Artifact_pipeline(inputDir, outputDir, autoOptions, logSwitch)
%ARTIFACT_PIPELINE 编排自动坏段识别、人工复核和统一切割。
%   可读取原始BDF连续数据或_segment.mat，输出_artifact.mat。
%   人工channel=0覆盖整份数据时排除该文件且不生成输出；输入保持不变。

    if nargin < 4 || isempty(logSwitch)
        logSwitch = "on";
    end

    [logFile, logEnabled] = ...
        HyperEEG.MultiCH.misc.InitLogFile([], "artifact", logSwitch);

    if logEnabled
        diary(char(logFile));
        diary on
        diaryCleanup = onCleanup(@() closeDiary());
    end

    fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf("开始伪迹坏段处理流程\n");

    if nargin < 3 || isempty(autoOptions)
        autoOptions = struct();
    end

    autoOptions = HyperEEG.MultiCH.main.ArtifactOptions(autoOptions);

    if ~exist(inputDir, "dir")
        error("inputDir不存在：%s", inputDir);
    end

    if ~exist(outputDir, "dir")
        mkdir(outputDir);
    end

    inputDir = string(inputDir);
    outputDir = string(outputDir);
    outputFiles = strings(0, 1);
    excludedFiles = strings(0, 1);
    [inputFiles, inputTypes] = collectInputFiles( ...
        inputDir, autoOptions.inputType);

    if isempty(inputFiles)
        warning("inputDir中未找到符合inputType=%s的BDF或_segment.mat：%s", ...
            autoOptions.inputType, inputDir);
        return;
    end

    nfile = numel(inputFiles);

    fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf("开始伪迹坏段处理，共 %d 个文件\n", nfile);

    for ifile = 1:nfile
        HyperEEG.MultiCH.misc.WorkflowCancel("throw");
        filepath = inputFiles(ifile);
        inputType = inputTypes(ifile);
        [~, name, ext] = fileparts(filepath);
        currentfilename = string(name) + string(ext);
        outputPath = buildArtifactOutputPath(outputDir, string(name));

        fprintf('\n[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        fprintf("正在处理第 %d 个数据 %s，共 %d 个\n", ...
            ifile, currentfilename, nfile);
        fprintf("当前进度为 %.2f%%\n", ifile / nfile * 100);

        try
            EEGdata = loadInputEEGdata(filepath, inputType);
        catch ME
            warning("读取输入失败：%s\n%s", filepath, ME.message);
            continue;
        end
        EEGdata = HyperEEG.MultiCH.core.ProcessStatus(EEGdata);
        EEGdata = HyperEEG.MultiCH.core.ProcessStatus(EEGdata, ...
            ["artifact_auto", "artifact_manual", ...
            "artifact_segment", "artifact_complete"], 0);

        %%======================================================
        % 自动识别坏段
        %%======================================================

        fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        fprintf("正在进行 %s 的自动坏段识别\n", currentfilename);

        if autoOptions.auto.enabled
            try
                [autoSegment, autoEmpty] = ...
                    HyperEEG.MultiCH.main.DataArtifact_Auto( ...
                    EEGdata, autoOptions);
                EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                    EEGdata, "artifact_auto", 1);
            catch ME
                warning("自动坏段识别失败：%s\n%s", filepath, ME.message);
                autoSegment = struct('channel', {}, 'intervals', {});
                autoEmpty = 1;
            end
        else
            fprintf("自动坏段识别已关闭\n");
            autoSegment = struct('channel', {}, 'intervals', {});
            autoEmpty = 1;
        end

        EEGdata.artifact.auto = autoSegment;
        HyperEEG.MultiCH.misc.WorkflowCancel("throw");

        if autoEmpty == 1
            fprintf("自动识别未发现坏段\n");
        else
            fprintf("自动识别发现 %d 个坏段区间\n", ...
                countInterval(autoSegment));
        end

        %%======================================================
        % 人工复核坏段
        %%======================================================

        fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        fprintf("正在进行 %s 的人工坏段复核\n", currentfilename);

        if autoOptions.manual.enabled
            try
                [manualSegment, cancelbool, excludeFileBool] = ...
                    HyperEEG.MultiCH.main.DataArtifact_Manual( ...
                    EEGdata, currentfilename);
            catch ME
                warning("人工坏段复核失败：%s\n%s", filepath, ME.message);
                continue;
            end
        else
            fprintf("人工坏段复核已关闭\n");
            manualSegment = struct('channel', {}, 'intervals', {});
            cancelbool = 0;
            excludeFileBool = 0;
        end

        if cancelbool == 1
            HyperEEG.MultiCH.misc.WorkflowCancel("throw");
            warning("用户取消 %s 的人工复核，已跳过该文件。", ...
                currentfilename);
            continue;
        end

        if excludeFileBool == 1
            excludedFiles(end + 1, 1) = filepath; %#ok<AGROW>

            % 清除同名旧派生结果，保证重新运行后输出数量真实反映排除结果。
            if isfile(outputPath)
                try
                    delete(char(outputPath));
                    fprintf("已删除同名旧输出：%s\n", outputPath);
                catch ME
                    warning("无法删除已排除文件的旧输出：%s\n%s", ...
                        outputPath, ME.message);
                end
            end

            fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
            fprintf("%s 已标记为全部通道无效，整文件排除，" + ...
                "不进入后续流程\n", currentfilename);
            continue;
        end

        EEGdata.artifact.manual = manualSegment;
        HyperEEG.MultiCH.misc.WorkflowCancel("throw");
        if autoOptions.manual.enabled
            EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                EEGdata, "artifact_manual", 1);
        end

        if isempty(manualSegment)
            fprintf("人工复核未标记坏段\n");
        else
            fprintf("人工复核标记 %d 个坏段区间\n", ...
                countInterval(manualSegment));
        end

        %%======================================================
        % 统一切割并保存
        %%======================================================

        allSegment = [autoSegment, manualSegment];

        fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

        if autoOptions.apply.enabled
            fprintf("正在合并标记并排除坏段\n");
            try
                [EEGdata, removedSampleCount, maskedValueCount] = ...
                    HyperEEG.MultiCH.main.DataArtifact_segment( ...
                    EEGdata, allSegment);
                EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                    EEGdata, "artifact_segment", 1);
            catch ME
                warning("坏段切割失败：%s\n%s", filepath, ME.message);
                continue;
            end
        else
            fprintf("应用坏段标记已关闭，仅保存标记\n");
            removedSampleCount = 0;
            maskedValueCount = 0;
        end

        EEGdata.artifact.options = autoOptions;
        EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
            EEGdata, "artifact_complete", 1);

        if ~isfield(EEGdata, "file")
            EEGdata.file = struct();
        end

        EEGdata.file.artifactpath = outputPath;
        HyperEEG.MultiCH.misc.WorkflowCancel("throw");

        try
            save(char(outputPath), "EEGdata");
        catch ME
            warning("结果保存失败：%s\n%s", outputPath, ME.message);
            continue;
        end

        outputFiles(end + 1, 1) = outputPath; %#ok<AGROW>

        fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        fprintf("完成 %s 的坏段处理，共排除 %d 个全局采样点，" + ...
            "屏蔽 %d 个通道采样值\n", ...
            currentfilename, removedSampleCount, maskedValueCount);
        fprintf("已保存至 %s\n", outputPath);
    end

    fprintf('\n[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf("完成全部伪迹坏段处理：输入%d个，成功输出%d个，" + ...
        "整文件排除%d个\n", nfile, numel(outputFiles), ...
        numel(excludedFiles));

end

function [inputFiles, inputTypes] = collectInputFiles(inputDir, inputType)
%COLLECTINPUTFILES 按明确优先级收集BDF或已分段MAT输入。

    matFiles = HyperEEG.MultiCH.misc.getFiles(inputDir, 'mat');
    segmentFiles = matFiles(endsWith( ...
        matFiles, "_segment.mat", "IgnoreCase", true));
    bdfFiles = HyperEEG.MultiCH.misc.getFiles(inputDir, 'bdf');
    inputType = lower(string(inputType));

    switch inputType
        case "segment"
            inputFiles = segmentFiles;
            inputTypes = repmat("segment", numel(inputFiles), 1);
        case "bdf"
            inputFiles = bdfFiles;
            inputTypes = repmat("bdf", numel(inputFiles), 1);
        otherwise
            % 兼容原流程：存在_segment.mat时优先使用，避免同一记录重复处理。
            if ~isempty(segmentFiles)
                inputFiles = segmentFiles;
                inputTypes = repmat("segment", numel(inputFiles), 1);
            else
                inputFiles = bdfFiles;
                inputTypes = repmat("bdf", numel(inputFiles), 1);
            end
    end

end


function EEGdata = loadInputEEGdata(filepath, inputType)
%LOADINPUTEEGDATA 统一读取连续BDF或项目MAT数据。

    if inputType == "bdf"
        EEGdata = HyperEEG.MultiCH.core.EEGdataFromBDF(filepath);
        return;
    end

    loadedData = load(char(filepath));

    if ~isfield(loadedData, "EEGdata")
        error("MAT文件中不存在变量EEGdata：%s", filepath);
    end

    EEGdata = loadedData.EEGdata;

end


function outputPath = buildArtifactOutputPath(outputDir, inputName)
%BUILDARTIFACTOUTPUTPATH 保持主体名称不变，仅替换阶段后缀。

    if endsWith(inputName, "_segment", "IgnoreCase", true)
        outputName = extractBefore(inputName, ...
            strlength(inputName) - strlength("_segment") + 1) + ...
            "_artifact.mat";
    else
        outputName = inputName + "_artifact.mat";
    end

    outputPath = fullfile(outputDir, outputName);

end

function intervalCount = countInterval(segmentInfo)
%COUNTINTERVAL 统计channel/intervals结构中的总区间数。

    intervalCount = 0;

    for isegment = 1:numel(segmentInfo)
        intervalCount = intervalCount + ...
            size(segmentInfo(isegment).intervals, 1);
    end

end

function closeDiary()
%CLOSEDIARY 确保成功、取消或异常退出时关闭日志。

    diary off

end

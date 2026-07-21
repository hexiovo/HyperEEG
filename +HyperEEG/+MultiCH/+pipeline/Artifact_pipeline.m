function [outputFiles, excludedFiles] = ...
        Artifact_pipeline(inputDir, outputDir, autoOptions, logSwitch)
%ARTIFACT_PIPELINE 编排自动坏段识别、人工复核和统一切割。
%   只读取_segment.mat，输出_artifact.mat。人工channel=0覆盖整份数据时
%   排除该文件且不生成输出；原始_segment.mat保持不变。

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
    files = HyperEEG.MultiCH.misc.getFiles(inputDir, 'mat');
    segmentfiles = files(endsWith(files, ...
        "_segment.mat", "IgnoreCase", true));

    if isempty(segmentfiles)
        warning("inputDir中未找到任何_segment.mat文件：%s", inputDir);
        return;
    end

    nfile = numel(segmentfiles);

    fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf("开始伪迹坏段处理，共 %d 个文件\n", nfile);

    for ifile = 1:nfile
        filepath = segmentfiles(ifile);
        [~, name, ext] = fileparts(filepath);
        currentfilename = string(name) + string(ext);
        outputPath = buildArtifactOutputPath(outputDir, string(name));

        fprintf('\n[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        fprintf("正在处理第 %d 个数据 %s，共 %d 个\n", ...
            ifile, currentfilename, nfile);
        fprintf("当前进度为 %.2f%%\n", ifile / nfile * 100);

        try
            cdata = load(char(filepath));
        catch ME
            warning("读取MAT文件失败：%s\n%s", filepath, ME.message);
            continue;
        end

        if ~isfield(cdata, "EEGdata")
            warning("MAT文件中不存在变量EEGdata：%s", filepath);
            continue;
        end

        EEGdata = cdata.EEGdata;
        EEGdata = HyperEEG.MultiCH.core.ProcessStatus(EEGdata);
        EEGdata = HyperEEG.MultiCH.core.ProcessStatus(EEGdata, ...
            ["artifact_auto", "artifact_manual", ...
            "artifact_segment", "artifact_complete"], 0);

        %%======================================================
        % 自动识别坏段
        %%======================================================

        fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        fprintf("正在进行 %s 的自动坏段识别\n", currentfilename);

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

        EEGdata.artifact.auto = autoSegment;

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

        try
            [manualSegment, cancelbool, excludeFileBool] = ...
                HyperEEG.MultiCH.main.DataArtifact_Manual( ...
                EEGdata, currentfilename);
        catch ME
            warning("人工坏段复核失败：%s\n%s", filepath, ME.message);
            continue;
        end

        if cancelbool == 1
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
        EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
            EEGdata, "artifact_manual", 1);

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
        fprintf("正在合并标记并排除坏段\n");
        try
            [EEGdata, removedSampleCount, maskedValueCount] = ...
                HyperEEG.MultiCH.main.DataArtifact_segment( ...
                EEGdata, allSegment);
            EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                EEGdata, ["artifact_segment", ...
                "artifact_complete"], 1);
        catch ME
            warning("坏段切割失败：%s\n%s", filepath, ME.message);
            continue;
        end

        if ~isfield(EEGdata, "file")
            EEGdata.file = struct();
        end

        EEGdata.file.artifactpath = outputPath;

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

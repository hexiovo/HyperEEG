function outputFiles = Preprocess_pipeline( ...
        inputDir, outputDir, options, logSwitch)
%PREPROCESS_PIPELINE 批量完成_artifact.mat到_clean.mat的预处理。
%   执行顺序为重采样、去趋势、带通、Notch、可选重参考、自动伪迹、
%   人工ICA成分选择、最终通道频域复核。参数和结果写入处理历史。
%   outputFiles只返回成功保存的文件；单文件异常会记录warning后继续。

    if nargin < 4 || isempty(logSwitch)
        logSwitch = "on";
    end

    % 日志必须在参数和路径检查前启动，确保早期错误也能被记录。
    [logFile, logEnabled] = ...
        HyperEEG.MultiCH.misc.InitLogFile([], "preprocess", logSwitch);

    if logEnabled
        diary(char(logFile));
        diary on
        diaryCleanup = onCleanup(@() closeDiary()); %#ok<NASGU>
    end

    fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf("开始脑电预处理流程\n");

    if nargin < 3 || isempty(options)
        options = struct();
    end

    options = HyperEEG.MultiCH.main.PreprocessOptions(options);

    if ~exist(inputDir, "dir")
        error("inputDir不存在：%s", inputDir);
    end

    if ~exist(outputDir, "dir")
        mkdir(outputDir);
    end

    inputDir = string(inputDir);
    outputDir = string(outputDir);
    files = HyperEEG.MultiCH.misc.getFiles(inputDir, 'mat');
    % 严格限制阶段输入，防止重复处理_clean.mat或误读其它MAT文件。
    artifactFiles = files(endsWith( ...
        files, "_artifact.mat", "IgnoreCase", true));
    outputFiles = strings(0, 1);
    excludedFileCount = 0;

    if isempty(artifactFiles)
        warning("inputDir中未找到任何_artifact.mat文件：%s", inputDir);
        return;
    end

    nfile = numel(artifactFiles);
    fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf("发现 %d 个待预处理文件\n", nfile);

    for ifile = 1:nfile
        filepath = artifactFiles(ifile);
        [~, inputName, inputExt] = fileparts(filepath);
        currentfilename = string(inputName) + string(inputExt);

        fprintf('\n[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        fprintf("正在处理第 %d 个数据 %s，共 %d 个\n", ...
            ifile, currentfilename, nfile);
        fprintf("当前进度为 %.2f%%\n", ifile / nfile * 100);

        % 单文件读取失败不终止整批任务。
        try
            loadedData = load(char(filepath));
        catch ME
            warning("读取MAT文件失败：%s\n%s", filepath, ME.message);
            continue;
        end

        if ~isfield(loadedData, "EEGdata")
            warning("MAT文件中不存在变量EEGdata：%s", filepath);
            continue;
        end

        EEGdata = loadedData.EEGdata;

        % 一个文件的任一步失败时不保存半成品，继续处理下一文件。
        try
            validateEEGdata(EEGdata);
            sourceRate = ...
                HyperEEG.MultiCH.core.PreprocessSampleRate(EEGdata);
            EEGdata = initializePreprocessing( ...
                EEGdata, filepath, options, sourceRate);

            %%==================================================
            % 可选重采样
            %%==================================================
            if options.resample.enabled
                [EEGdata, stepInfo] = runStep( ...
                    EEGdata, "重采样", options.resample, ...
                    @() HyperEEG.MultiCH.main.DataPreprocess_Resample( ...
                    EEGdata, options.resample));
                EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                    EEGdata, "resample", 1);
            else
                fprintf("跳过重采样，当前采样率为 %.6g Hz\n", sourceRate);
            end

            %%==================================================
            % 去趋势
            %%==================================================
            if options.detrend.enabled
                [EEGdata, stepInfo] = runStep( ...
                    EEGdata, "去趋势", options.detrend, ...
                    @() HyperEEG.MultiCH.main.DataPreprocess_Detrend( ...
                    EEGdata, options.detrend));
                EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                    EEGdata, "detrend", 1);
            else
                fprintf("跳过去趋势\n");
            end

            %%==================================================
            % 带通滤波
            %%==================================================
            if options.bandpass.enabled
                [EEGdata, stepInfo] = runStep( ...
                    EEGdata, "带通滤波", options.bandpass, ...
                    @() HyperEEG.MultiCH.main.DataPreprocess_Bandpass( ...
                    EEGdata, options.bandpass));
                EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                    EEGdata, "bandpass", 1);
            else
                fprintf("跳过带通滤波\n");
            end

            %%==================================================
            % 50 Hz工频滤波
            %%==================================================
            if options.notch.enabled
                [EEGdata, stepInfo] = runStep( ...
                    EEGdata, "工频滤波", options.notch, ...
                    @() HyperEEG.MultiCH.main.DataPreprocess_Notch( ...
                    EEGdata, options.notch));
                EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                    EEGdata, "notch", 1);
            else
                fprintf("跳过工频滤波\n");
            end

            %%==================================================
            % 鲁棒重参考（额外的必要预处理）
            %%==================================================
            if options.reference.enabled
                [EEGdata, stepInfo] = runStep( ...
                    EEGdata, "重参考", options.reference, ...
                    @() HyperEEG.MultiCH.main.DataPreprocess_Reference( ...
                    EEGdata, options.reference));
                EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                    EEGdata, "reference", 1);
            else
                fprintf("跳过重参考\n");
            end

            %%==================================================
            % 自动伪迹处理
            %%==================================================
            if options.artifact.enabled && ...
                    options.artifact.auto.enabled
                methodsText = strjoin(string( ...
                    options.artifact.auto.methods), ",");
                fprintf("自动伪迹方法：%s\n", methodsText);
                [EEGdata, stepInfo] = runStep( ...
                    EEGdata, "自动伪迹处理", ...
                    options.artifact.auto, ...
                    @() HyperEEG.MultiCH.main.DataPreprocess_ArtifactAuto( ...
                    EEGdata, options.artifact.auto));
            else
                fprintf("跳过自动伪迹处理\n");
            end

            %%==================================================
            % 人工ICA与最终频域复核循环
            % 若最终复核新增整条坏导，从首次ICA前数据恢复、屏蔽累计坏导，
            % 再对剩余通道重新ICA，直到本轮不再新增坏导。
            %%==================================================
            preICAData = EEGdata.data;
            cumulativeBadChannels = find(all( ...
                isnan(preICAData) | isinf(preICAData), 2))';
            reviewRound = 0;
            skipCurrentFile = false;

            while true
                reviewRound = reviewRound + 1;

                if options.artifact.enabled && ...
                        options.artifact.icaManual.enabled
                    inputSampleCount = size(EEGdata.data, 2);
                    fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
                    fprintf("开始第%d轮人工ICA成分复核\n", reviewRound);
                    [EEGdata, stepInfo, cancelbool] = ...
                        HyperEEG.MultiCH.main. ...
                        DataPreprocess_ArtifactICAManual( ...
                        EEGdata, currentfilename, ...
                        options.artifact.icaManual);

                    if cancelbool == 1
                        warning("用户取消 %s 的人工ICA复核，已跳过该文件。", ...
                            currentfilename);
                        skipCurrentFile = true;
                        break;
                    end

                    EEGdata = appendHistory(EEGdata, ...
                        "人工ICA成分复核_第" + string(reviewRound) + "轮", ...
                        options.artifact.icaManual, stepInfo, ...
                        inputSampleCount);
                    fprintf("完成第%d轮人工ICA，删除成分：%s\n", ...
                        reviewRound, ...
                        componentText(stepInfo.rejectedComponents));
                else
                    fprintf("跳过人工ICA成分复核\n");
                end

                if ~(options.artifact.enabled && ...
                        options.artifact.manual.enabled)
                    fprintf("跳过最终通道频域人工复核\n");
                    break;
                end

                inputSampleCount = size(EEGdata.data, 2);
                fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
                fprintf("开始第%d轮最终通道频域人工复核\n", reviewRound);
                allowRerunICA = options.artifact.enabled && ...
                    options.artifact.icaManual.enabled;
                [EEGdata, stepInfo, cancelbool, excludeFileBool, ...
                        rerunICABool] = ...
                    HyperEEG.MultiCH.main.DataPreprocess_ArtifactManual( ...
                    EEGdata, currentfilename, allowRerunICA);

                if rerunICABool == 1
                    % 返回首次人工ICA前的信号；此前已确认的坏导仍保持屏蔽。
                    EEGdata.data = preICAData;
                    EEGdata.data(cumulativeBadChannels, :) = NaN;
                    fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
                    fprintf("用户在第%d轮频域复核请求返回上一步，" + ...
                        "即将重新进行ICA。\n", reviewRound);
                    continue;
                end

                if cancelbool == 1
                    warning("用户取消 %s 的通道频域复核，已跳过该文件。", ...
                        currentfilename);
                    skipCurrentFile = true;
                    break;
                end

                if excludeFileBool == 1
                    excludedFileCount = excludedFileCount + 1;
                    outputPath = buildCleanOutputPath( ...
                        outputDir, string(inputName));

                    if isfile(outputPath)
                        try
                            delete(char(outputPath));
                            fprintf("已删除同名旧输出：%s\n", outputPath);
                        catch ME
                            warning("无法删除已排除文件的旧输出：%s\n%s", ...
                                outputPath, ME.message);
                        end
                    end

                    fprintf("%s 已标记为全部通道无效，整文件排除，" + ...
                        "不保存_clean.mat\n", currentfilename);
                    skipCurrentFile = true;
                    break;
                end

                EEGdata = appendHistory(EEGdata, ...
                    "最终通道频域复核_第" + string(reviewRound) + "轮", ...
                    options.artifact.manual, stepInfo, inputSampleCount);
                newBadChannels = setdiff( ...
                    stepInfo.badChannels, cumulativeBadChannels);
                allReviewedBadChannels = union( ...
                    cumulativeBadChannels, stepInfo.badChannels);
                EEGdata.artifact.frequencyManual.badChannels = ...
                    allReviewedBadChannels;
                fprintf("完成第%d轮频域复核，新增坏导：%s\n", ...
                    reviewRound, componentText(newBadChannels));

                if isempty(newBadChannels)
                    break;
                end

                cumulativeBadChannels = union( ...
                    cumulativeBadChannels, newBadChannels);

                if ~options.artifact.icaManual.enabled
                    warning("人工ICA已关闭，坏导已屏蔽但无法自动重启ICA。");
                    break;
                end

                remainingChannels = setdiff( ...
                    1:size(preICAData, 1), cumulativeBadChannels);

                if numel(remainingChannels) < 2
                    warning("排除坏导后少于两个有效通道，当前文件不再适合ICA。");
                    skipCurrentFile = true;
                    break;
                end

                % 只恢复信号本体；保留前几轮人工记录和处理历史。
                EEGdata.data = preICAData;
                EEGdata.data(cumulativeBadChannels, :) = NaN;
                fprintf("从首次ICA前数据恢复，累计排除坏导%s，" + ...
                    "即将重新ICA。\n", ...
                    componentText(cumulativeBadChannels));
            end

            if skipCurrentFile
                continue;
            end
        catch ME
            warning("预处理失败：%s\n%s", filepath, ...
                getReport(ME, 'extended', 'hyperlinks', 'off'));
            continue;
        end

        outputPath = buildCleanOutputPath( ...
            outputDir, string(inputName));
        EEGdata.preprocessing.completedAt_bjt = currentBJT();
        EEGdata.preprocessing.outputPath = outputPath;
        EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
            EEGdata, "preprocess_complete", 1);
        [EEGdata, qualityInfo] = ...
            HyperEEG.MultiCH.core.DataQualitySummary(EEGdata);

        if ~isfield(EEGdata, "file")
            EEGdata.file = struct();
        end

        EEGdata.file.cleanpath = outputPath;

        % 只有全部启用步骤成功完成后才写入_clean.mat。
        try
            save(char(outputPath), "EEGdata");
        catch ME
            warning("结果保存失败：%s\n%s", outputPath, ME.message);
            continue;
        end

        outputFiles(end + 1, 1) = outputPath; %#ok<AGROW>
        fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        fprintf("完成 %s 的预处理，已保存至 %s\n", ...
            currentfilename, outputPath);
        fprintf("坏导：%s；总体有效比例：%.2f%%\n", ...
            componentText(qualityInfo.badchannel), ...
            qualityInfo.totalEffectiveRate * 100);
    end

    fprintf('\n[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf("完成全部脑电预处理，共保存%d个文件，整文件排除%d个\n", ...
        numel(outputFiles), excludedFileCount);

end

function outputText = componentText(componentIndex)
%COMPONENTTEXT 将成分序号格式化为适合日志的一行文本。

    if isempty(componentIndex)
        outputText = "无";
    else
        outputText = strjoin(string(componentIndex), ",");
    end

end

function outputPath = buildCleanOutputPath(outputDir, inputName)
%BUILDCLEANOUTPUTPATH 保持主体名称不变，仅替换阶段后缀。

    outputName = regexprep(inputName, ...
        '_artifact$', '', 'ignorecase') + "_clean.mat";
    outputPath = fullfile(outputDir, outputName);

end

function [EEGdata, info] = runStep( ...
        EEGdata, stepName, parameters, stepFunction)
%RUNSTEP 统一打印步骤日志，并在成功后追加处理历史。

    inputSampleCount = size(EEGdata.data, 2);
    fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf("开始%s\n", stepName);
    [EEGdata, info] = stepFunction();
    EEGdata = appendHistory( ...
        EEGdata, stepName, parameters, info, inputSampleCount);
    fprintf("完成%s\n", stepName);

end

function EEGdata = initializePreprocessing( ...
        EEGdata, inputPath, options, sourceRate)
%INITIALIZEPREPROCESSING 初始化本次运行的采样率与可追溯信息。

    EEGdata = HyperEEG.MultiCH.core.ProcessStatus(EEGdata);
    EEGdata = HyperEEG.MultiCH.core.ProcessStatus(EEGdata, ...
        ["resample", "detrend", "bandpass", "notch", ...
        "reference", "preprocess_auto", "robust", "asr", ...
        "ica", "ica_auto", "ica_manual", ...
        "preprocess_manual", "preprocess_complete", ...
        "quality_summary"], 0);

    if ~isfield(EEGdata, "etc")
        EEGdata.etc = struct();
    end

    if ~isfield(EEGdata.etc, "samplerate") || ...
            ~isstruct(EEGdata.etc.samplerate)
        EEGdata.etc.samplerate = struct('raw', sourceRate);
    elseif ~isfield(EEGdata.etc.samplerate, "raw")
        EEGdata.etc.samplerate.raw = sourceRate;
    end

    EEGdata.etc.samplerate.clean = sourceRate;
    EEGdata.preprocessing = struct();
    EEGdata.preprocessing.inputPath = string(inputPath);
    EEGdata.preprocessing.options = options;
    EEGdata.preprocessing.startedAt_bjt = currentBJT();
    EEGdata.preprocessing.history = struct( ...
        'step', {}, 'parameters', {}, 'details', {}, ...
        'inputSamples', {}, 'outputSamples', {}, ...
        'executedAt_bjt', {}, 'matlabVersion', {});

end

function EEGdata = appendHistory( ...
        EEGdata, stepName, parameters, details, inputSampleCount)
%APPENDHISTORY 保存步骤参数、结果、样本数、北京时间和MATLAB版本。

    historyItem.step = string(stepName);
    historyItem.parameters = parameters;
    historyItem.details = details;
    historyItem.inputSamples = inputSampleCount;
    historyItem.outputSamples = size(EEGdata.data, 2);
    historyItem.executedAt_bjt = currentBJT();
    historyItem.matlabVersion = string(version);
    EEGdata.preprocessing.history(end + 1) = historyItem;

end

function validateEEGdata(EEGdata)
%VALIDATEEEGDATA 检查预处理所需的最小EEGdata数据契约。

    if ~isstruct(EEGdata) || ~isscalar(EEGdata) || ...
            ~isfield(EEGdata, "data") || ...
            ~isfield(EEGdata, "times")
        error("EEGdata必须是包含data和times字段的标量结构体。");
    end

    if ~isnumeric(EEGdata.data) || ~ismatrix(EEGdata.data) || ...
            isempty(EEGdata.data)
        error("EEGdata.data必须是非空的通道×采样点数值矩阵。");
    end

    if ~isnumeric(EEGdata.times) || ...
            numel(EEGdata.times) ~= size(EEGdata.data, 2)
        error("EEGdata.times必须与data采样点数一致，单位为毫秒。");
    end

end

function timeText = currentBJT()
%CURRENTBJT 返回带时区标识的北京时间文本。

    timeText = string(datetime('now', ...
        'TimeZone', 'Asia/Shanghai', ...
        'Format', 'yyyy-MM-dd HH:mm:ss Z'));

end

function closeDiary()
%CLOSEDIARY 由onCleanup调用，确保成功或异常退出时均关闭日志。

    diary off

end

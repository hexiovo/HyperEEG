function results = Workflow_pipeline(config, order, progressCallback)
%WORKFLOW_PIPELINE 按用户选择编排“先分段”或“先预处理”完整流程。
%   order为segment_first或preprocess_first。preprocess_first会在连续BDF
%   上完成坏段和预处理，每个文件只进行一次人工ICA，最后才按Marker切段。

    if nargin < 3 || isempty(progressCallback)
        progressCallback = @(message) fprintf('[%s] %s\n', ...
            datestr(now, 'yyyy-mm-dd HH:MM:SS'), message);
    end

    config = HyperEEG.MultiCH.main.WorkflowOptions(config);
    order = lower(string(order));

    if ~any(order == ["segment_first", "preprocess_first"])
        error("order必须为segment_first或preprocess_first。");
    end

    validatePaths(config);
    results = struct('order', order, 'segmentinfo', [], ...
        'artifactFiles', strings(0, 1), ...
        'excludedFiles', strings(0, 1), ...
        'cleanFiles', strings(0, 1), ...
        'segmentFiles', strings(0, 1), ...
        'completed', false, 'status', "");

    if order == "segment_first"
        results = runSegmentFirst(config, results, progressCallback);
    else
        results = runPreprocessFirst(config, results, progressCallback);
    end

    if results.completed
        progressCallback("工作流完成");
    else
        progressCallback("工作流已安全停止：" + results.status);
    end

end


function results = runSegmentFirst(config, results, notify)
%RUNSEGMENTFIRST 兼容原顺序：分段后再逐片段进行坏段和预处理。

    currentInput = string(config.paths.rawInputDir);
    currentType = "bdf";

    if config.stages.segment.enabled
        notify("开始Marker检查与数据分段");
        results.segmentinfo = HyperEEG.MultiCH.pipeline.segment_pipeline( ...
            config.paths.rawInputDir, config.paths.segmentOutputDir, ...
            config.paths.dataIgnorePath, config.logSwitch, ...
            config.paths.segmentPlanPath, true);
        currentInput = string(config.paths.segmentOutputDir);
        currentType = "segment";
    end

    if config.stages.artifact.enabled
        notify("开始坏段识别与人工复核");
        artifactOptions = config.artifactOptions;
        artifactOptions.inputType = currentType;
        [results.artifactFiles, results.excludedFiles] = ...
            HyperEEG.MultiCH.pipeline.Artifact_pipeline( ...
            currentInput, config.paths.artifactOutputDir, ...
            artifactOptions, config.logSwitch);

        if isempty(results.artifactFiles)
            results.status = "坏段阶段没有生成有效输出；可能已取消当前文件。";
            notify(results.status + "本次不再继续预处理或分段。");
            return;
        end

        currentInput = string(config.paths.artifactOutputDir);
        currentType = "artifact";
    end

    if config.stages.preprocess.enabled
        notify("开始脑电预处理");
        preprocessOptions = config.preprocessOptions;
        preprocessOptions.inputType = currentType;
        preprocessOptions.inputFiles = results.artifactFiles;
        results.cleanFiles = HyperEEG.MultiCH.pipeline.Preprocess_pipeline( ...
            currentInput, config.paths.cleanOutputDir, ...
            preprocessOptions, config.logSwitch);
    end

    results.completed = true;
    results.status = "完成";

end


function results = runPreprocessFirst(config, results, notify)
%RUNPREPROCESSFIRST 连续数据先清洗，最后执行事件分段。

    currentInput = string(config.paths.rawInputDir);
    currentType = "bdf";

    if config.stages.artifact.enabled
        notify("开始连续BDF坏段识别与人工复核");
        artifactOptions = config.artifactOptions;
        artifactOptions.inputType = "bdf";
        [results.artifactFiles, results.excludedFiles] = ...
            HyperEEG.MultiCH.pipeline.Artifact_pipeline( ...
            currentInput, config.paths.artifactOutputDir, ...
            artifactOptions, config.logSwitch);

        if isempty(results.artifactFiles)
            results.status = "坏段阶段没有生成有效输出。";
            notify(results.status + "若没有新增坏段，请点击" + ...
                "“确认（可无新增坏段）”，不要关闭或取消窗口。" + ...
                "本次流程已安全停止。");
            return;
        end

        currentInput = string(config.paths.artifactOutputDir);
        currentType = "artifact";
    end

    if config.stages.preprocess.enabled
        notify("开始连续数据预处理；每份BDF只进入一次人工ICA");
        preprocessOptions = config.preprocessOptions;
        preprocessOptions.inputType = currentType;

        if currentType == "artifact"
            preprocessOptions.inputFiles = results.artifactFiles;
        end

        results.cleanFiles = HyperEEG.MultiCH.pipeline.Preprocess_pipeline( ...
            currentInput, config.paths.cleanOutputDir, ...
            preprocessOptions, config.logSwitch);

        if isempty(results.cleanFiles)
            results.status = "预处理阶段没有生成有效输出。";
            notify(results.status + "本次不执行最终分段。");
            return;
        end
        currentInput = string(config.paths.cleanOutputDir);
        currentType = "clean";
    end

    if config.stages.segment.enabled
        notify("开始生成分段计划；此时仍不重新执行预处理");
        results.segmentinfo = HyperEEG.MultiCH.pipeline.segment_pipeline( ...
            config.paths.rawInputDir, config.paths.segmentOutputDir, ...
            config.paths.dataIgnorePath, config.logSwitch, ...
            config.paths.segmentPlanPath, false);

        if currentType == "bdf"
            HyperEEG.MultiCH.main.segment_Marker( ...
                results.segmentinfo, string(config.paths.segmentOutputDir));
            results.segmentFiles = listSegmentOutputs( ...
                config.paths.segmentOutputDir);
        else
            results.segmentFiles = HyperEEG.MultiCH.main.segment_EEGdata( ...
                results.segmentinfo, currentInput, ...
                config.paths.segmentOutputDir);
        end
    end

    results.completed = true;
    results.status = "完成";

end


function validatePaths(config)
%VALIDATEPATHS 在运行任何阶段前检查所需路径。

    if ~exist(config.paths.rawInputDir, 'dir')
        error("原始BDF目录不存在：%s", config.paths.rawInputDir);
    end

    requiredOutput = strings(0, 1);

    if config.stages.segment.enabled
        requiredOutput(end + 1) = string(config.paths.segmentOutputDir);
    end

    if config.stages.artifact.enabled
        requiredOutput(end + 1) = string(config.paths.artifactOutputDir);
    end

    if config.stages.preprocess.enabled
        requiredOutput(end + 1) = string(config.paths.cleanOutputDir);
    end

    if any(strlength(requiredOutput) == 0)
        error("所有启用阶段都必须设置输出目录。");
    end

    for ipath = 1:numel(requiredOutput)
        if ~exist(requiredOutput(ipath), 'dir')
            mkdir(requiredOutput(ipath));
        end
    end

    optionalFiles = [string(config.paths.dataIgnorePath), ...
        string(config.paths.segmentPlanPath)];

    for ifile = 1:numel(optionalFiles)
        if strlength(optionalFiles(ifile)) > 0 && ...
                ~isfile(optionalFiles(ifile))
            error("配置文件不存在：%s", optionalFiles(ifile));
        end
    end

end


function files = listSegmentOutputs(outputDir)
%LISTSEGMENTOUTPUTS 返回当前目录中分段输出，用于统一结果结构。

    allFiles = HyperEEG.MultiCH.misc.getFiles(outputDir, 'mat');
    files = allFiles(endsWith(allFiles, "_segment.mat", ...
        "IgnoreCase", true));

end

function results = Workflow_pipeline(config, order, progressCallback)
%WORKFLOW_PIPELINE 按用户选择编排“先分段”或“先预处理”完整流程。
%   order为segment_first或preprocess_first。preprocess_first会在连续BDF
%   上完成坏段和预处理，每个文件只进行一次人工ICA，最后才按Marker切段。

    if nargin < 3 || isempty(progressCallback)
        progressCallback = @(message) fprintf('[%s] %s\n', ...
            datestr(now, 'yyyy-mm-dd HH:MM:SS'), message);
    end

    % 先统一补齐默认值，再进行任何建目录或读文件操作。这样配置错误不会
    % 留下看似有效的空输出目录，也不会在长批处理运行到一半才暴露。
    config = HyperEEG.MultiCH.main.WorkflowOptions(config);
    order = lower(string(order));

    if ~any(order == ["segment_first", "preprocess_first"])
        error("order必须为segment_first或preprocess_first。");
    end

    validatePaths(config);
    % 两种顺序使用同一结果契约。调用方不需要根据按钮判断字段是否存在，
    % 未启用或未成功完成的阶段保持空数组，不能伪装成“已处理”。
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

    % currentInput/currentType始终描述“下一阶段真正应读取的产物”。
    % 每完成一个阶段就推进二者，避免后续误读原BDF或重复处理旧MAT。
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
        % 先分段时坏段阶段读取_segment.mat；若用户关闭分段，则允许直接
        % 读取BDF。inputType显式传递，避免同一目录混有多种文件时选错。
        artifactOptions = config.artifactOptions;
        artifactOptions.inputType = currentType;
        [results.artifactFiles, results.excludedFiles] = ...
            HyperEEG.MultiCH.pipeline.Artifact_pipeline( ...
            currentInput, config.paths.artifactOutputDir, ...
            artifactOptions, config.logSwitch);

        % 空输出既可能来自取消，也可能来自所有文件均无效。无论原因如何，
        % 都不能让预处理回退到目录扫描，否则可能误处理上次运行的旧文件。
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
        % artifact启用时用返回的成功文件白名单限制输入；该白名单能够排除
        % 本轮取消、读取失败或整文件无效的项目，防止旧同名产物混入。
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

    % 本顺序的核心约束是：坏段与ICA均作用于连续记录，最后只切割一次。
    % 因此整个预处理阶段不得把segmentOutputDir作为输入。
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

        % “没有人工新增坏段”是正常确认，不会导致空输出；真正的空输出表示
        % 当前批次没有可继续的数据，所以必须安全停止而不是报错退出。
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

        % artifact阶段可能只成功处理部分文件。显式白名单保证预处理不会因
        % 扫描目录而捡到失败文件或先前批次遗留的_artifact.mat。
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
        % 分段边界仍从原始BDF的Marker/采样率建立；实际切割对象则是clean
        % 连续数据。这样既保留事件来源，又不会重新触发任何预处理步骤。
        notify("开始生成分段计划；此时仍不重新执行预处理");
        results.segmentinfo = HyperEEG.MultiCH.pipeline.segment_pipeline( ...
            config.paths.rawInputDir, config.paths.segmentOutputDir, ...
            config.paths.dataIgnorePath, config.logSwitch, ...
            config.paths.segmentPlanPath, false);

        if currentType == "bdf"
            % 用户只启用分段时直接走原始BDF导出路径。
            HyperEEG.MultiCH.main.segment_Marker( ...
                results.segmentinfo, string(config.paths.segmentOutputDir));
            results.segmentFiles = listSegmentOutputs( ...
                config.paths.segmentOutputDir);
        else
            % 已有artifact/clean连续数据时按绝对time_ms选择对应样本；
            % segment_EEGdata负责保留公共时间轴和处理历史。
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

    % 原始目录永远只读；这里只检查存在性，所有mkdir均限定在用户明确填写
    % 且属于已启用阶段的派生输出目录。
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

    % 空字符串表示不使用可选表格；非空时必须在开始前验证，以免BDF已处理
    % 很久后才因XLSX路径错误而失败。
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

    % segmentinfo.mat也是MAT文件，但它只是计划元数据，不能作为数据结果。
    allFiles = HyperEEG.MultiCH.misc.getFiles(outputDir, 'mat');
    files = allFiles(endsWith(allFiles, "_segment.mat", ...
        "IgnoreCase", true));

end

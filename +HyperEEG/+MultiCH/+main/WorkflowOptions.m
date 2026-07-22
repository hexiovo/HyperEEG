function config = WorkflowOptions(userConfig)
%WORKFLOWOPTIONS 补齐并验证统一工作流配置。

    % 路径默认留空，强制由UI/调用方明确选择。尤其不把原始目录复用为
    % 输出目录，避免任何派生文件与只读BDF混放。
    defaults.paths.rawInputDir = "";
    defaults.paths.segmentOutputDir = "";
    defaults.paths.artifactOutputDir = "";
    defaults.paths.cleanOutputDir = "";
    defaults.paths.dataIgnorePath = "";
    defaults.paths.segmentPlanPath = "";
    defaults.stages.segment.enabled = true;
    defaults.stages.artifact.enabled = true;
    defaults.stages.preprocess.enabled = true;
    defaults.logSwitch = "on";
    defaults.artifactOptions = struct();
    defaults.preprocessOptions = struct();

    if nargin < 1 || isempty(userConfig)
        userConfig = struct();
    end

    % 递归合并允许只覆盖一个深层参数，同时保留其余稳定默认值。
    config = mergeStruct(defaults, userConfig);
    config.artifactOptions = ...
        HyperEEG.MultiCH.main.ArtifactOptions(config.artifactOptions);
    config.preprocessOptions = ...
        HyperEEG.MultiCH.main.PreprocessOptions(config.preprocessOptions);
    stageNames = ["segment", "artifact", "preprocess"];

    % 接受logical和数值0/1，兼容MATLAB UI控件与旧脚本；其它非零数值
    % 不按“真”处理，以免拼写/读取错误悄悄打开某个阶段。
    for istage = 1:numel(stageNames)
        value = config.stages.(stageNames(istage)).enabled;

        if ~((islogical(value) && isscalar(value)) || ...
                (isnumeric(value) && isscalar(value) && ...
                ismember(value, [0, 1])))
            error("stages.%s.enabled必须为布尔值。", stageNames(istage));
        end
    end

    if ~any(strcmpi(string(config.logSwitch), ["on", "off"]))
        error("logSwitch必须为on或off。");
    end

end


function output = mergeStruct(defaultValue, userValue)
%MERGESTRUCT 递归合并工作流配置。

    if ~isstruct(userValue) || ~isscalar(userValue)
        error("工作流配置必须为标量结构体。");
    end

    output = defaultValue;
    fields = fieldnames(userValue);

    for ifield = 1:numel(fields)
        name = fields{ifield};

        if isfield(output, name) && isstruct(output.(name)) && ...
                isstruct(userValue.(name))
            output.(name) = mergeStruct(output.(name), userValue.(name));
        else
            output.(name) = userValue.(name);
        end
    end

end

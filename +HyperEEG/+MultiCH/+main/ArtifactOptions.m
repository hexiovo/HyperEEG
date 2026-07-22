function options = ArtifactOptions(userOptions)
%ARTIFACTOPTIONS 补齐并验证Artifact_pipeline的全部参数。
%   保留旧版平铺检测参数；新增输入类型及自动、人工、应用标记开关。

    defaults.inputType = "auto";
    defaults.auto.enabled = true;
    defaults.manual.enabled = true;
    defaults.apply.enabled = true;
    defaults.windowDuration_s = 2;
    defaults.windowOverlap = 0.5;
    defaults.robustZThreshold = 6;
    defaults.severeZThreshold = 10;
    defaults.minMetricVotes = 2;
    defaults.minBadChannelRatio = 0.25;
    defaults.covarianceZThreshold = 6;
    defaults.covarianceRegularization = 1e-6;
    defaults.flatScaleRatio = 1e-4;
    defaults.mergeGap_s = 0.25;
    defaults.minWindowCount = 8;

    if nargin < 1 || isempty(userOptions)
        userOptions = struct();
    end

    if ~isstruct(userOptions) || ~isscalar(userOptions)
        error("Artifact options必须为标量结构体。");
    end

    options = mergeStruct(defaults, userOptions);
    validInputType = ["auto", "bdf", "segment"];

    if ~any(strcmpi(string(options.inputType), validInputType))
        error("artifact.inputType必须为auto、bdf或segment。");
    end

    validateEnabled(options.auto.enabled, "auto.enabled");
    validateEnabled(options.manual.enabled, "manual.enabled");
    validateEnabled(options.apply.enabled, "apply.enabled");
    validateattributes(options.windowDuration_s, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(options.windowOverlap, {'numeric'}, ...
        {'scalar', 'real', 'finite', '>=', 0, '<', 1});
    validateattributes(options.robustZThreshold, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(options.severeZThreshold, {'numeric'}, ...
        {'scalar', 'real', 'finite', '>', options.robustZThreshold});
    validateattributes(options.minMetricVotes, {'numeric'}, ...
        {'scalar', 'integer', '>=', 1, '<=', 4});
    validateattributes(options.minBadChannelRatio, {'numeric'}, ...
        {'scalar', 'real', '>', 0, '<=', 1});
    validateattributes(options.covarianceZThreshold, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(options.covarianceRegularization, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(options.flatScaleRatio, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive', '<', 1});
    validateattributes(options.mergeGap_s, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'nonnegative'});
    validateattributes(options.minWindowCount, {'numeric'}, ...
        {'scalar', 'integer', 'positive'});

end


function output = mergeStruct(defaultValue, userValue)
%MERGESTRUCT 递归合并默认值与用户覆盖值。

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


function validateEnabled(value, name)
%VALIDATEENABLED 验证布尔开关。

    valid = (islogical(value) && isscalar(value)) || ...
        (isnumeric(value) && isscalar(value) && ismember(value, [0, 1]));

    if ~valid
        error("%s必须为true、false、1或0。", name);
    end

end

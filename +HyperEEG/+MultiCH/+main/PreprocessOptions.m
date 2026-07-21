function options = PreprocessOptions(options)
%PREPROCESSOPTIONS 合并、迁移并验证Preprocess_pipeline参数。
%   用户只需填写希望覆盖的字段；其余字段由默认值补齐。旧版
%   artifact.method及其平铺参数会迁移到artifact.auto结构。

    if nargin < 1 || isempty(options)
        options = struct();
    end

    %% 各步骤默认参数：优先保留低通道数据，不默认进行激进处理
    defaults.resample.enabled = false;
    defaults.resample.targetRate = 250;

    defaults.detrend.enabled = true;
    defaults.detrend.method = "linear";

    defaults.bandpass.enabled = true;
    defaults.bandpass.profile = "broadband";
    defaults.bandpass.rangeHz = [];
    defaults.bandpass.order = 4;

    defaults.notch.enabled = true;
    defaults.notch.lineFrequencyHz = 50;
    defaults.notch.bandwidthHz = 2;
    defaults.notch.order = 2;

    defaults.reference.enabled = false;
    defaults.reference.method = "median";
    defaults.reference.channels = [];

    defaults.artifact.enabled = true;
    defaults.artifact.auto.enabled = true;
    defaults.artifact.auto.methods = ["robust", "asr"];
    defaults.artifact.auto.robustZ = 8;
    defaults.artifact.auto.robustWindow_s = 1;
    defaults.artifact.auto.icaKurtosisZ = 6;
    defaults.artifact.auto.icaHighFrequencyZ = 6;
    defaults.artifact.auto.icaMaxRejectFraction = 0.25;
    defaults.artifact.auto.icaRejectComponents = [];
    defaults.artifact.auto.asrBurstCriterion = 20;
    defaults.artifact.auto.asrMaxMemoryMB = 512;
    defaults.artifact.icaManual.enabled = true;
    defaults.artifact.manual.enabled = true;

    % 先迁移旧字段再递归合并，确保旧脚本仍能获得新结构。
    options = migrateArtifactOptions(options);

    options = mergeStruct(defaults, options);
    validateOptions(options);

end

function validateOptions(options)
%VALIDATEOPTIONS 在读取文件前集中检查配置，避免批处理中途才失败。

    textOptions = {options.detrend.method, ...
        options.bandpass.profile, options.reference.method};

    for itext = 1:numel(textOptions)
        if ~(ischar(textOptions{itext}) || ...
                (isstring(textOptions{itext}) && ...
                isscalar(textOptions{itext})))
            error("预处理method和profile必须为文本标量。");
        end
    end

    stepNames = ["resample", "detrend", "bandpass", ...
        "notch", "reference", "artifact"];

    for istep = 1:numel(stepNames)
        enabledValue = options.(stepNames(istep)).enabled;

        if ~(islogical(enabledValue) && isscalar(enabledValue)) && ...
                ~(isnumeric(enabledValue) && isscalar(enabledValue) && ...
                ismember(enabledValue, [0, 1]))
            error("%s.enabled必须为true、false、1或0。", ...
                stepNames(istep));
        end
    end

    validateEnabled(options.artifact.auto.enabled, ...
        "artifact.auto.enabled");
    validateEnabled(options.artifact.icaManual.enabled, ...
        "artifact.icaManual.enabled");
    validateEnabled(options.artifact.manual.enabled, ...
        "artifact.manual.enabled");

    validateattributes(options.resample.targetRate, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});

    if ~any(strcmpi(string(options.detrend.method), ...
            ["linear", "constant"]))
        error("detrend.method必须为linear或constant。");
    end

    validProfile = ["broadband", "connectivity", "erp", ...
        "time_frequency", "slow", "custom"];

    if ~any(strcmpi(string(options.bandpass.profile), validProfile))
        error("bandpass.profile不是有效预设。");
    end

    if ~isempty(options.bandpass.rangeHz)
        validateattributes(options.bandpass.rangeHz, {'numeric'}, ...
            {'vector', 'numel', 2, 'real', 'finite', 'positive'});
    elseif strcmpi(string(options.bandpass.profile), "custom")
        error("bandpass.profile为custom时必须设置rangeHz。");
    end

    validateattributes(options.bandpass.order, {'numeric'}, ...
        {'scalar', 'integer', 'positive'});
    validateattributes(options.notch.lineFrequencyHz, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(options.notch.bandwidthHz, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(options.notch.order, {'numeric'}, ...
        {'scalar', 'integer', 'positive'});

    if ~any(strcmpi(string(options.reference.method), ...
            ["median", "average", "channel", "none"]))
        error("reference.method必须为median、average、channel或none。");
    end

    methods = normalizeMethods(options.artifact.auto.methods);
    validMethods = ["robust", "ica", "asr", "none"];

    if any(~ismember(methods, validMethods))
        error("artifact.auto.methods只能包含robust、ica、asr或none。");
    end

    if any(methods == "none") && numel(methods) > 1
        error("artifact.auto.methods中的none不能与其它方法同时使用。");
    end

    % 中位数参考是非线性变换；当前执行顺序下不能放在ICA之前。
    if options.reference.enabled && ...
            strcmpi(string(options.reference.method), "median") && ...
            options.artifact.enabled && ...
            ((options.artifact.auto.enabled && any(methods == "ica")) || ...
            options.artifact.icaManual.enabled)
        error("当前Pipeline中位数重参考位于ICA之前，会破坏ICA的" + ...
            "线性假设；请关闭重参考或改用average/channel。");
    end

    validateattributes(options.artifact.auto.robustZ, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(options.artifact.auto.robustWindow_s, ...
        {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(options.artifact.auto.icaMaxRejectFraction, ...
        {'numeric'}, {'scalar', 'real', 'finite', '>=', 0, '<=', 1});
    validateattributes(options.artifact.auto.icaKurtosisZ, ...
        {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(options.artifact.auto.icaHighFrequencyZ, ...
        {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});

    if ~isempty(options.artifact.auto.icaRejectComponents)
        validateattributes(options.artifact.auto.icaRejectComponents, ...
            {'numeric'}, {'vector', 'integer', 'positive'});
    end

    validateattributes(options.artifact.auto.asrBurstCriterion, ...
        {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(options.artifact.auto.asrMaxMemoryMB, ...
        {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});

end

function validateEnabled(value, optionName)
%VALIDATEENABLED 验证步骤开关，接受logical或数值0/1。

    if ~(islogical(value) && isscalar(value)) && ...
            ~(isnumeric(value) && isscalar(value) && ...
            ismember(value, [0, 1]))
        error("%s必须为true、false、1或0。", optionName);
    end

end

function methods = normalizeMethods(methods)
%NORMALIZEMETHODS 规范自动方法列表并保证至少包含一种方法。

    if iscellstr(methods) %#ok<ISCLSTR>
        methods = string(methods);
    elseif ischar(methods)
        methods = string(methods);
    end

    if ~isstring(methods) || isempty(methods)
        error("artifact.auto.methods必须为非空文本或文本数组。");
    end

    methods = lower(methods(:)');

end

function options = migrateArtifactOptions(options)
%MIGRATEARTIFACTOPTIONS 将旧版单method参数映射到Auto/Manual新结构。

    if ~isstruct(options) || ~isfield(options, "artifact") || ...
            ~isstruct(options.artifact) || ...
            ~isfield(options.artifact, "method")
        return;
    end

    legacyMethod = lower(string(options.artifact.method));

    if legacyMethod == "manual"
        options.artifact.auto.enabled = false;
        options.artifact.icaManual.enabled = false;
        options.artifact.manual.enabled = true;
    else
        options.artifact.auto.methods = legacyMethod;
    end

    legacyFields = ["robustZ", "robustWindow_s", ...
        "icaKurtosisZ", "icaHighFrequencyZ", ...
        "icaMaxRejectFraction", "icaRejectComponents", ...
        "asrBurstCriterion", "asrMaxMemoryMB"];

    for ifield = 1:numel(legacyFields)
        currentField = legacyFields(ifield);

        if isfield(options.artifact, currentField)
            options.artifact.auto.(currentField) = ...
                options.artifact.(currentField);
        end
    end

end

function output = mergeStruct(defaultValue, userValue)
%MERGESTRUCT 递归覆盖默认结构，同时允许保留扩展字段。

    output = defaultValue;

    if ~isstruct(userValue)
        error("预处理options必须为结构体。");
    end

    userFields = fieldnames(userValue);

    for ifield = 1:numel(userFields)
        currentField = userFields{ifield};

        if isfield(output, currentField) && ...
                isstruct(output.(currentField)) && ...
                isstruct(userValue.(currentField))
            output.(currentField) = mergeStruct( ...
                output.(currentField), userValue.(currentField));
        else
            output.(currentField) = userValue.(currentField);
        end
    end

end

function options = StatisticsOptions(userOptions)
%STATISTICSOPTIONS 补齐并验证统计分析配置。

    defaults.inputDir = "";
    defaults.outputDir = "";
    defaults.groupFile = "";
    defaults.excelName = "time_domain_statistics";
    defaults.excel.enabled = true;
    defaults.excel.nonScalarMode = "long";
    defaults.excel.psdMode = "long";
    defaults.excel.periodicPeakMode = "long";
    defaults.excel.timeDomainLayout = "wide";
    defaults.excel.nonlinearScalarLayout = "wide";
    defaults.excel.nonlinearSeriesMode = "long";
    defaults.excel.rqaLocation = "main";
    defaults.excel.spectrumStride = 1;
    defaults.excel.maxRowsPerSheet = 900000;
    defaults.timeDomain.enabled = true;
    defaults.timeDomain.metrics = [ ...
        "mean", "median", "min", "max", "range", "peak_to_peak", ...
        "variance", "std", "mad", "iqr", "rms", ...
        "skewness", "kurtosis", "mean_abs_diff", "line_length", ...
        "zero_cross_rate", "hjorth_activity", "hjorth_mobility", ...
        "hjorth_complexity"];
    defaults.timeDomain.varianceNormalization = "sample";
    defaults.timeDomain.quantiles = [0.05, 0.25, 0.75, 0.95];
    defaults.timeDomain.quantileMethod = "linear";
    defaults.timeDomain.trimPercent = 10;
    defaults.timeDomain.madMethod = "median";
    defaults.timeDomain.shapeBiasCorrection = "biased";
    defaults.timeDomain.zeroCrossThreshold = 0;
    defaults.timeDomain.zeroCrossCenter = true;
    defaults.timeDomain.zeroCrossReference = "mean";
    defaults.timeDomain.zeroCrossNormalization = "proportion";
    defaults.timeDomain.lineLengthNormalization = "none";
    defaults.frequency.enabled = false;
    defaults.frequency.metrics = ["psd", "absolute_power", ...
        "relative_power", "log_power", "spectral_shape", ...
        "spectral_edge", "individual_alpha_peak", "spectral_flatness"];
    defaults.frequency.minimumSamples = 64;
    defaults.frequency.welch.windowSeconds = 2;
    defaults.frequency.welch.overlap = 0.5;
    defaults.frequency.welch.nfft = 512;
    defaults.frequency.welch.detrend = "constant";
    defaults.frequency.bands.names = ["delta", "theta", "alpha", ...
        "beta", "gamma"];
    defaults.frequency.bands.rangesHz = [1, 4; 4, 8; 8, 13; 13, 30; 30, 45];
    defaults.frequency.totalRangeHz = [1, 45];
    defaults.frequency.logTransform = "db";
    defaults.frequency.shape.frequencyRangeHz = [1, 45];
    defaults.frequency.shape.edgeFractions = [0.90, 0.95];
    defaults.frequency.shape.alphaPeakRangeHz = [7, 14];
    defaults.frequency.aperiodic.frequencyRangeHz = [2, 45];
    defaults.frequency.aperiodic.excludeRangesHz = [48, 52; 58, 62];
    defaults.frequency.aperiodic.peakThresholdSD = 2;
    defaults.frequency.aperiodic.minPeakDistanceHz = 1;
    defaults.frequency.aperiodic.maxPeaks = 6;
    defaults.frequency.faa.pairs = ["F3", "F4"; "F7", "F8"];
    defaults.frequency.faa.direction = "right_minus_left";
    defaults.frequency.faa.transform = "natural_log";
    defaults.nonlinear.enabled = false;
    defaults.nonlinear.metrics = [ ...
        "spectral_entropy", "differential_entropy", "sample_entropy", ...
        "approximate_entropy", "permutation_entropy", "lempel_ziv", ...
        "hurst", "dfa", "higuchi_fd", "petrosian_fd", "katz_fd"];
    defaults.nonlinear.minimumSamples = 64;
    defaults.nonlinear.maxSamples = 3000;
    defaults.nonlinear.spectral.frequencyRangeHz = [0.5, 45];
    defaults.nonlinear.spectral.method = "welch";
    defaults.nonlinear.spectral.windowSeconds = 2;
    defaults.nonlinear.spectral.overlap = 0.5;
    defaults.nonlinear.spectral.nfft = 512;
    defaults.nonlinear.spectral.normalized = true;
    defaults.nonlinear.entropy.m = 2;
    defaults.nonlinear.entropy.r = 0.2;
    defaults.nonlinear.entropy.rMode = "std";
    defaults.nonlinear.entropy.distance = "chebyshev";
    defaults.nonlinear.entropy.standardization = "zscore";
    defaults.nonlinear.entropy.fuzzyPower = 2;
    defaults.nonlinear.differential.method = "gaussian";
    defaults.nonlinear.differential.histogramBins = 32;
    defaults.nonlinear.permutation.dimension = 3;
    defaults.nonlinear.permutation.delay = 1;
    defaults.nonlinear.permutation.normalized = true;
    defaults.nonlinear.svd.dimension = 3;
    defaults.nonlinear.svd.delay = 1;
    defaults.nonlinear.svd.normalized = true;
    defaults.nonlinear.lempelZiv.binarization = "median";
    defaults.nonlinear.lempelZiv.normalized = true;
    defaults.nonlinear.hurst.scaleMin = 16;
    defaults.nonlinear.hurst.scaleMax = 512;
    defaults.nonlinear.hurst.nScales = 12;
    defaults.nonlinear.dfa.scaleMin = 16;
    defaults.nonlinear.dfa.scaleMax = 512;
    defaults.nonlinear.dfa.nScales = 12;
    defaults.nonlinear.dfa.order = 1;
    defaults.nonlinear.fractal.higuchiKmax = 10;
    defaults.nonlinear.multiscale.maxScale = 20;
    defaults.nonlinear.correlationDimension.dimension = 3;
    defaults.nonlinear.correlationDimension.delay = 1;
    defaults.nonlinear.correlationDimension.theilerWindow = 20;
    defaults.nonlinear.correlationDimension.maxPoints = 1000;
    defaults.nonlinear.correlationDimension.nRadii = 12;
    defaults.nonlinear.correlationDimension.radiusPercentiles = [5, 60];
    defaults.nonlinear.lyapunov.dimension = 3;
    defaults.nonlinear.lyapunov.delay = 1;
    defaults.nonlinear.lyapunov.theilerWindow = 20;
    defaults.nonlinear.lyapunov.maxPoints = 1000;
    defaults.nonlinear.lyapunov.maxSteps = 20;
    defaults.nonlinear.rqa.embeddingDimension = 3;
    defaults.nonlinear.rqa.delay = 1;
    defaults.nonlinear.rqa.maxPoints = 1000;
    defaults.nonlinear.rqa.thresholdMode = "fixed";
    defaults.nonlinear.rqa.distance = "euclidean";
    defaults.nonlinear.rqa.epsilon = 0.5;
    defaults.nonlinear.rqa.targetRR = 0.05;
    defaults.nonlinear.rqa.theilerWindow = 1;
    defaults.nonlinear.rqa.minDiagonalLine = 2;
    defaults.nonlinear.rqa.minVerticalLine = 2;
    defaults.nonlinear.rqa.storeMatrixInMat = true;
    defaults.nonlinear.rqa.exportMatrixToExcel = false;
    defaults.nonlinear.rqa.matrixExcelMode = "coordinates";
    defaults.missing.method = "omit";
    defaults.missing.maxFraction = 0.20;
    defaults.missing.minimumValidSamples = 3;

    if nargin < 1 || isempty(userOptions)
        userOptions = struct();
    end

    options = mergeStruct(defaults, userOptions);
    % 兼容V0.8/V0.9脚本：旧nonScalarMode仅在未显式指定新字段时映射。
    if isfield(userOptions, 'excel') && isstruct(userOptions.excel) && ...
            isfield(userOptions.excel, 'nonScalarMode')
        if ~isfield(userOptions.excel, 'psdMode')
            options.excel.psdMode = options.excel.nonScalarMode;
        end
        if ~isfield(userOptions.excel, 'periodicPeakMode')
            options.excel.periodicPeakMode = options.excel.nonScalarMode;
        end
    end
    requiredPaths = ["inputDir", "outputDir"];

    for ipath = 1:numel(requiredPaths)
        name = requiredPaths(ipath);
        value = strtrim(string(options.(name)));

        if ~isscalar(value) || strlength(value) == 0
            error("%s不能为空。", name);
        end

        options.(name) = value;
    end

    options.groupFile = strtrim(string(options.groupFile));
    options.excelName = regexprep(strtrim(string(options.excelName)), ...
        '\.xlsx$', '', 'ignorecase');

    if strlength(options.excelName) == 0 || ...
            any(contains(options.excelName, ["/", "\", ":", "*", "?", ...
            '"', "<", ">", "|"]))
        error("excelName必须是有效的工作簿基本名称。不要包含路径或非法字符。");
    end

    validateLogical(options.timeDomain.enabled, "timeDomain.enabled");
    validateLogical(options.frequency.enabled, "frequency.enabled");
    validateLogical(options.nonlinear.enabled, "nonlinear.enabled");
    validateLogical(options.excel.enabled, "excel.enabled");
    validateChoice(options.excel.nonScalarMode, ...
        ["long", "wide", "separate", "none"], ...
        "excel.nonScalarMode");
    validateChoice(options.excel.psdMode, ...
        ["long", "wide", "separate", "none"], "excel.psdMode");
    validateChoice(options.excel.periodicPeakMode, ...
        ["long", "wide", "separate", "none"], ...
        "excel.periodicPeakMode");
    validateChoice(options.excel.timeDomainLayout, ...
        ["wide", "long", "both", "none"], "excel.timeDomainLayout");
    validateChoice(options.excel.nonlinearScalarLayout, ...
        ["wide", "long", "both", "none"], ...
        "excel.nonlinearScalarLayout");
    validateChoice(options.excel.nonlinearSeriesMode, ...
        ["long", "wide", "separate", "none"], ...
        "excel.nonlinearSeriesMode");
    validateChoice(options.excel.rqaLocation, ["main", "separate"], ...
        "excel.rqaLocation");
    validateInteger(options.excel.spectrumStride, 1, inf, ...
        "excel.spectrumStride");
    validateInteger(options.excel.maxRowsPerSheet, 1000, 1048575, ...
        "excel.maxRowsPerSheet");

    if ~options.timeDomain.enabled && ~options.frequency.enabled && ...
            ~options.nonlinear.enabled
        error("至少需要启用一种统计计算方法。");
    end

    allowedMetrics = [ ...
        "mean", "median", "min", "max", "range", "peak_to_peak", ...
        "quantiles", "trimmed_mean", "variance", "std", "mad", ...
        "iqr", "rms", "coefficient_of_variation", "energy", ...
        "sum_abs", "skewness", "kurtosis", "mean_abs_diff", ...
        "line_length", "zero_cross_rate", "hjorth_activity", ...
        "hjorth_mobility", "hjorth_complexity"];
    metrics = unique(lower(string(options.timeDomain.metrics(:)')), 'stable');

    if any(~ismember(metrics, allowedMetrics))
        error("存在不支持的时域指标：%s", ...
            strjoin(metrics(~ismember(metrics, allowedMetrics)), ", "));
    end

    if options.timeDomain.enabled && isempty(metrics)
        error("启用时域统计后至少需要选择一个指标。");
    end

    options.timeDomain.metrics = metrics;
    validateChoice(options.timeDomain.varianceNormalization, ...
        ["sample", "population"], "timeDomain.varianceNormalization");
    validateChoice(options.timeDomain.zeroCrossNormalization, ...
        ["proportion", "per_second"], ...
        "timeDomain.zeroCrossNormalization");
    validateChoice(options.timeDomain.lineLengthNormalization, ...
        ["none", "per_sample", "per_second"], ...
        "timeDomain.lineLengthNormalization");
    validateLogical(options.timeDomain.zeroCrossCenter, ...
        "timeDomain.zeroCrossCenter");
    validateChoice(options.timeDomain.quantileMethod, ...
        ["linear", "nearest", "lower", "higher", "midpoint"], ...
        "timeDomain.quantileMethod");
    validateChoice(options.timeDomain.madMethod, ["median", "mean"], ...
        "timeDomain.madMethod");
    validateChoice(options.timeDomain.shapeBiasCorrection, ...
        ["biased", "bias_corrected"], ...
        "timeDomain.shapeBiasCorrection");
    validateChoice(options.timeDomain.zeroCrossReference, ...
        ["mean", "median", "zero"], "timeDomain.zeroCrossReference");

    quantiles = double(options.timeDomain.quantiles(:)');

    if any(~isfinite(quantiles)) || any(quantiles <= 0 | quantiles >= 1) || ...
            any(diff(quantiles) <= 0)
        error("timeDomain.quantiles必须是在0和1之间严格递增的数值。");
    end

    options.timeDomain.quantiles = quantiles;
    validateScalarRange(options.timeDomain.trimPercent, 0, 50, ...
        false, "timeDomain.trimPercent");
    validateScalarRange(options.timeDomain.zeroCrossThreshold, 0, inf, ...
        true, "timeDomain.zeroCrossThreshold");
    allowedFrequency = ["psd", "absolute_power", "relative_power", ...
        "log_power", "spectral_shape", "aperiodic", ...
        "theta_beta_ratio", "alpha_theta_ratio", "high_low_ratio", ...
        "faa", "spectral_edge", "individual_alpha_peak", ...
        "spectral_flatness"];
    frequencyMetrics = unique(lower(string( ...
        options.frequency.metrics(:)')), 'stable');
    if any(~ismember(frequencyMetrics, allowedFrequency))
        error("存在不支持的频谱/频带指标：%s", strjoin( ...
            frequencyMetrics(~ismember(frequencyMetrics, allowedFrequency)), ...
            ", "));
    end
    if options.frequency.enabled && isempty(frequencyMetrics)
        error("启用频谱与频带后至少需要选择一个指标。");
    end
    options.frequency.metrics = frequencyMetrics;
    validateInteger(options.frequency.minimumSamples, 8, inf, ...
        "frequency.minimumSamples");
    validateScalarRange(options.frequency.welch.windowSeconds, 0, inf, ...
        false, "frequency.welch.windowSeconds");
    validateScalarRange(options.frequency.welch.overlap, 0, 1, false, ...
        "frequency.welch.overlap");
    validateInteger(options.frequency.welch.nfft, 8, inf, ...
        "frequency.welch.nfft");
    validateChoice(options.frequency.welch.detrend, ...
        ["none", "constant", "linear"], "frequency.welch.detrend");
    bandNames = strtrim(string(options.frequency.bands.names(:)));
    bandRanges = double(options.frequency.bands.rangesHz);
    if isempty(bandNames) || size(bandRanges, 1) ~= numel(bandNames) || ...
            size(bandRanges, 2) ~= 2 || any(~isfinite(bandRanges), 'all') || ...
            any(bandRanges(:, 1) < 0) || ...
            any(bandRanges(:, 2) <= bandRanges(:, 1)) || ...
            any(strlength(bandNames) == 0) || ...
            numel(unique(lower(bandNames))) ~= numel(bandNames)
        error("frequency.bands必须包含唯一名称及对应的递增Hz上下界。");
    end
    options.frequency.bands.names = bandNames';
    options.frequency.bands.rangesHz = bandRanges;
    validateVectorRange(options.frequency.totalRangeHz, 0, inf, ...
        "frequency.totalRangeHz");
    validateChoice(options.frequency.logTransform, ["db", "log10"], ...
        "frequency.logTransform");
    validateVectorRange(options.frequency.shape.frequencyRangeHz, 0, inf, ...
        "frequency.shape.frequencyRangeHz");
    edges = double(options.frequency.shape.edgeFractions(:)');
    if isempty(edges) || any(~isfinite(edges)) || any(edges <= 0 | edges >= 1)
        error("frequency.shape.edgeFractions必须在0和1之间。");
    end
    options.frequency.shape.edgeFractions = unique(edges, 'stable');
    validateVectorRange(options.frequency.shape.alphaPeakRangeHz, 0, inf, ...
        "frequency.shape.alphaPeakRangeHz");
    validateVectorRange(options.frequency.aperiodic.frequencyRangeHz, 0, inf, ...
        "frequency.aperiodic.frequencyRangeHz");
    validateRangeMatrix(options.frequency.aperiodic.excludeRangesHz, ...
        "frequency.aperiodic.excludeRangesHz");
    validateScalarRange(options.frequency.aperiodic.peakThresholdSD, ...
        0, inf, false, "frequency.aperiodic.peakThresholdSD");
    validateScalarRange(options.frequency.aperiodic.minPeakDistanceHz, ...
        0, inf, false, "frequency.aperiodic.minPeakDistanceHz");
    validateInteger(options.frequency.aperiodic.maxPeaks, 0, 100, ...
        "frequency.aperiodic.maxPeaks");
    pairs = string(options.frequency.faa.pairs);
    if isempty(pairs), pairs = strings(0, 2); end
    if size(pairs, 2) ~= 2 || any(strlength(strtrim(pairs)) == 0, 'all')
        error("frequency.faa.pairs必须为N×2左右电极名称矩阵。");
    end
    options.frequency.faa.pairs = strtrim(pairs);
    validateChoice(options.frequency.faa.direction, ...
        ["right_minus_left", "left_minus_right"], ...
        "frequency.faa.direction");
    validateChoice(options.frequency.faa.transform, ...
        ["natural_log", "log10", "db"], "frequency.faa.transform");
    allowedNonlinear = ["spectral_entropy", "differential_entropy", ...
        "sample_entropy", "approximate_entropy", "fuzzy_entropy", ...
        "permutation_entropy", "svd_entropy", "lempel_ziv", "hurst", ...
        "dfa", "higuchi_fd", "petrosian_fd", "katz_fd", ...
        "multiscale_entropy", "correlation_dimension", ...
        "largest_lyapunov", "rqa"];
    nonlinearMetrics = unique(lower(string(options.nonlinear.metrics(:)')), ...
        'stable');

    if any(~ismember(nonlinearMetrics, allowedNonlinear))
        error("存在不支持的熵/非线性指标：%s", strjoin( ...
            nonlinearMetrics(~ismember(nonlinearMetrics, allowedNonlinear)), ...
            ", "));
    end

    if options.nonlinear.enabled && isempty(nonlinearMetrics)
        error("启用熵与非线性动力学后至少需要选择一个指标。");
    end

    options.nonlinear.metrics = nonlinearMetrics;
    validateInteger(options.nonlinear.minimumSamples, 8, inf, ...
        "nonlinear.minimumSamples");
    validateInteger(options.nonlinear.maxSamples, ...
        options.nonlinear.minimumSamples, inf, "nonlinear.maxSamples");
    validateVectorRange(options.nonlinear.spectral.frequencyRangeHz, ...
        0, inf, "nonlinear.spectral.frequencyRangeHz");
    validateChoice(options.nonlinear.spectral.method, ...
        ["welch", "periodogram"], "nonlinear.spectral.method");
    validateScalarRange(options.nonlinear.spectral.windowSeconds, 0, inf, ...
        false, "nonlinear.spectral.windowSeconds");
    validateScalarRange(options.nonlinear.spectral.overlap, 0, 1, false, ...
        "nonlinear.spectral.overlap");
    validateInteger(options.nonlinear.spectral.nfft, 8, inf, ...
        "nonlinear.spectral.nfft");
    validateLogical(options.nonlinear.spectral.normalized, ...
        "nonlinear.spectral.normalized");
    validateInteger(options.nonlinear.entropy.m, 1, 8, ...
        "nonlinear.entropy.m");
    validateScalarRange(options.nonlinear.entropy.r, 0, inf, false, ...
        "nonlinear.entropy.r");
    validateChoice(options.nonlinear.entropy.rMode, ["std", "absolute"], ...
        "nonlinear.entropy.rMode");
    validateChoice(options.nonlinear.entropy.distance, ...
        ["chebyshev", "euclidean"], "nonlinear.entropy.distance");
    validateChoice(options.nonlinear.entropy.standardization, ...
        ["zscore", "demean", "none"], ...
        "nonlinear.entropy.standardization");
    validateScalarRange(options.nonlinear.entropy.fuzzyPower, 0, inf, false, ...
        "nonlinear.entropy.fuzzyPower");
    validateChoice(options.nonlinear.differential.method, ...
        ["gaussian", "histogram"], "nonlinear.differential.method");
    validateInteger(options.nonlinear.differential.histogramBins, 4, 512, ...
        "nonlinear.differential.histogramBins");
    validateInteger(options.nonlinear.permutation.dimension, 2, 7, ...
        "nonlinear.permutation.dimension");
    validateInteger(options.nonlinear.permutation.delay, 1, inf, ...
        "nonlinear.permutation.delay");
    validateLogical(options.nonlinear.permutation.normalized, ...
        "nonlinear.permutation.normalized");
    validateInteger(options.nonlinear.svd.dimension, 2, 20, ...
        "nonlinear.svd.dimension");
    validateInteger(options.nonlinear.svd.delay, 1, inf, ...
        "nonlinear.svd.delay");
    validateLogical(options.nonlinear.svd.normalized, ...
        "nonlinear.svd.normalized");
    validateChoice(options.nonlinear.lempelZiv.binarization, ...
        ["median", "mean", "zero"], "nonlinear.lempelZiv.binarization");
    validateLogical(options.nonlinear.lempelZiv.normalized, ...
        "nonlinear.lempelZiv.normalized");
    validateScaleOptions(options.nonlinear.hurst, "nonlinear.hurst");
    validateScaleOptions(options.nonlinear.dfa, "nonlinear.dfa");
    validateInteger(options.nonlinear.dfa.order, 1, 3, ...
        "nonlinear.dfa.order");
    validateInteger(options.nonlinear.fractal.higuchiKmax, 2, 100, ...
        "nonlinear.fractal.higuchiKmax");
    validateInteger(options.nonlinear.multiscale.maxScale, 2, 100, ...
        "nonlinear.multiscale.maxScale");
    validateEmbedding(options.nonlinear.correlationDimension, ...
        "nonlinear.correlationDimension");
    validateInteger(options.nonlinear.correlationDimension.nRadii, 5, 100, ...
        "nonlinear.correlationDimension.nRadii");
    validateVectorRange(options.nonlinear.correlationDimension.radiusPercentiles, ...
        0, 100, "nonlinear.correlationDimension.radiusPercentiles");
    validateEmbedding(options.nonlinear.lyapunov, "nonlinear.lyapunov");
    validateInteger(options.nonlinear.lyapunov.maxSteps, 3, inf, ...
        "nonlinear.lyapunov.maxSteps");
    validateInteger(options.nonlinear.rqa.embeddingDimension, 1, 20, ...
        "nonlinear.rqa.embeddingDimension");
    validateInteger(options.nonlinear.rqa.delay, 1, inf, ...
        "nonlinear.rqa.delay");
    validateInteger(options.nonlinear.rqa.maxPoints, 32, 5000, ...
        "nonlinear.rqa.maxPoints");
    validateChoice(options.nonlinear.rqa.thresholdMode, ...
        ["fixed", "target_rr"], "nonlinear.rqa.thresholdMode");
    validateChoice(options.nonlinear.rqa.distance, ...
        ["euclidean", "chebyshev"], "nonlinear.rqa.distance");
    validateScalarRange(options.nonlinear.rqa.epsilon, 0, inf, false, ...
        "nonlinear.rqa.epsilon");
    validateScalarRange(options.nonlinear.rqa.targetRR, 0, 1, false, ...
        "nonlinear.rqa.targetRR");
    validateInteger(options.nonlinear.rqa.theilerWindow, 0, ...
        options.nonlinear.rqa.maxPoints - 2, "nonlinear.rqa.theilerWindow");
    validateInteger(options.nonlinear.rqa.minDiagonalLine, 2, inf, ...
        "nonlinear.rqa.minDiagonalLine");
    validateInteger(options.nonlinear.rqa.minVerticalLine, 2, inf, ...
        "nonlinear.rqa.minVerticalLine");
    validateLogical(options.nonlinear.rqa.storeMatrixInMat, ...
        "nonlinear.rqa.storeMatrixInMat");
    validateLogical(options.nonlinear.rqa.exportMatrixToExcel, ...
        "nonlinear.rqa.exportMatrixToExcel");
    validateChoice(options.nonlinear.rqa.matrixExcelMode, ...
        ["coordinates", "dense"], "nonlinear.rqa.matrixExcelMode");
    validateChoice(options.missing.method, ...
        ["omit", "linear", "nearest", "previous", "zero", ...
        "reject_channel", "reject_file"], "missing.method");
    validateScalarRange(options.missing.maxFraction, 0, 1, true, ...
        "missing.maxFraction");

    if ~isnumeric(options.missing.minimumValidSamples) || ...
            ~isscalar(options.missing.minimumValidSamples) || ...
            ~isfinite(options.missing.minimumValidSamples) || ...
            options.missing.minimumValidSamples < 2 || ...
            fix(options.missing.minimumValidSamples) ~= ...
            options.missing.minimumValidSamples
        error("missing.minimumValidSamples必须是至少为2的整数。");
    end

end


function validateRangeMatrix(value, name)
    if isempty(value), return; end
    value = double(value);
    if size(value, 2) ~= 2 || any(~isfinite(value), 'all') || ...
            any(value(:, 1) < 0) || any(value(:, 2) <= value(:, 1))
        error("%s必须为N×2递增频率范围矩阵。", name);
    end
end


function validateScaleOptions(options, name)
    validateInteger(options.scaleMin, 4, inf, name + ".scaleMin");
    validateInteger(options.scaleMax, options.scaleMin + 1, inf, ...
        name + ".scaleMax");
    validateInteger(options.nScales, 3, 100, name + ".nScales");
end


function validateEmbedding(options, name)
    validateInteger(options.dimension, 1, 20, name + ".dimension");
    validateInteger(options.delay, 1, inf, name + ".delay");
    validateInteger(options.theilerWindow, 0, inf, name + ".theilerWindow");
    validateInteger(options.maxPoints, 32, 5000, name + ".maxPoints");
end


function validateVectorRange(value, lowerBound, upperBound, name)
    value = double(value(:)');

    if numel(value) ~= 2 || any(~isfinite(value)) || ...
            value(1) < lowerBound || value(2) > upperBound || ...
            value(2) <= value(1)
        error("%s必须为严格递增的二元素数值向量。", name);
    end
end


function validateInteger(value, lowerBound, upperBound, name)
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
            value < lowerBound || value > upperBound || fix(value) ~= value
        error("%s必须是允许范围内的整数。", name);
    end
end


function output = mergeStruct(defaultValue, userValue)
    if ~isstruct(userValue) || ~isscalar(userValue)
        error("统计配置必须为标量结构体。");
    end

    output = defaultValue;
    names = fieldnames(userValue);

    for iname = 1:numel(names)
        name = names{iname};

        if isfield(output, name) && isstruct(output.(name)) && ...
                isstruct(userValue.(name))
            output.(name) = mergeStruct(output.(name), userValue.(name));
        else
            output.(name) = userValue.(name);
        end
    end
end


function validateChoice(value, choices, name)
    if ~isscalar(string(value)) || ~ismember(lower(string(value)), choices)
        error("%s必须是以下选项之一：%s。", name, strjoin(choices, ", "));
    end
end


function validateLogical(value, name)
    if ~((islogical(value) && isscalar(value)) || ...
            (isnumeric(value) && isscalar(value) && ismember(value, [0, 1])))
        error("%s必须为布尔值。", name);
    end
end


function validateScalarRange(value, lowerBound, upperBound, includeUpper, name)
    valid = isnumeric(value) && isscalar(value) && isfinite(value) && ...
        value >= lowerBound;

    if includeUpper
        valid = valid && value <= upperBound;
    else
        valid = valid && value < upperBound;
    end

    if ~valid
        error("%s超出允许范围。", name);
    end
end

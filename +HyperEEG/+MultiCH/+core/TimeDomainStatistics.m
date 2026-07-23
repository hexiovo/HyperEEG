function [resultTable, info] = TimeDomainStatistics(data, sampleRate, options)
%TIMEDOMAINSTATISTICS 按通道计算可配置的时域统计特征。
%   数据为通道×采样点。结果每行对应一个通道，并保留样本量、缺失率和
%   缺失处理状态，便于后续质量控制和汇总分析。

    if ~isnumeric(data) || ~ismatrix(data) || isempty(data) || ~isreal(data)
        error("data必须为非空的通道×采样点实数矩阵。");
    end

    if ~isnumeric(sampleRate) || ~isscalar(sampleRate) || ...
            ~isfinite(sampleRate) || sampleRate <= 0
        error("sampleRate必须为正数。");
    end

    if isfield(options, 'timeDomain') && isfield(options, 'missing')
        timeOptions = options.timeDomain;
        timeOptions.missingMethod = options.missing.method;
        timeOptions.maxMissingFraction = options.missing.maxFraction;
        timeOptions.minimumValidSamples = options.missing.minimumValidSamples;
        options = timeOptions;
    else
        validated = HyperEEG.MultiCH.main.StatisticsOptions(struct( ...
            'inputDir', string(pwd), 'outputDir', string(pwd), ...
            'timeDomain', options));
        options = validated.timeDomain;
        options.missingMethod = validated.missing.method;
        options.maxMissingFraction = validated.missing.maxFraction;
        options.minimumValidSamples = validated.missing.minimumValidSamples;
    end
    nChannel = size(data, 1);
    nTotal = size(data, 2);
    metricNames = expandMetricNames(options.metrics, options.quantiles);
    values = NaN(nChannel, numel(metricNames));
    validCount = zeros(nChannel, 1);
    missingFraction = zeros(nChannel, 1);
    status = strings(nChannel, 1);

    for ichannel = 1:nChannel
        original = double(data(ichannel, :));
        invalid = ~isfinite(original);
        missingFraction(ichannel) = sum(invalid) / nTotal;
        [x, status(ichannel)] = prepareValues(original, options, ...
            missingFraction(ichannel));
        validCount(ichannel) = numel(x);

        if numel(x) < options.minimumValidSamples || status(ichannel) == "rejected"
            status(ichannel) = "insufficient_or_rejected";
            continue;
        end

        values(ichannel, :) = calculateMetrics(x, sampleRate, options, ...
            metricNames);
    end

    resultTable = table((1:nChannel)', repmat(nTotal, nChannel, 1), ...
        validCount, missingFraction, status, ...
        'VariableNames', {'channel_index', 'n_total', 'n_valid', ...
        'missing_fraction', 'missing_status'});

    for imetric = 1:numel(metricNames)
        resultTable.(metricNames(imetric)) = values(:, imetric);
    end

    info.sampleRate = sampleRate;
    info.sampleCount = nTotal;
    info.channelCount = nChannel;
    info.metrics = metricNames;
    info.options = options;

end


function [x, status] = prepareValues(original, options, missingFraction)
    method = lower(string(options.missingMethod));
    invalid = ~isfinite(original);

    if method == "reject_file" && missingFraction > options.maxMissingFraction
        error('HyperEEG:Statistics:RejectFile', ...
            '文件缺失比例超过阈值（%.3f > %.3f）。', ...
            missingFraction, options.maxMissingFraction);
    end

    if method == "reject_channel" && missingFraction > options.maxMissingFraction
        x = [];
        status = "rejected";
        return;
    end

    if ~any(invalid)
        x = original;
        status = "complete";
        return;
    end

    switch method
        case {"omit", "reject_channel", "reject_file"}
            x = original(~invalid);
            status = "omitted";
        case "zero"
            x = original;
            x(invalid) = 0;
            status = "filled_zero";
        case {"linear", "nearest"}
            validIndex = find(~invalid);

            if isempty(validIndex)
                x = [];
                status = "insufficient_or_rejected";
            elseif numel(validIndex) == 1
                x = repmat(original(validIndex), size(original));
                status = "filled_single_value";
            else
                x = original;
                x(invalid) = interp1(validIndex, original(validIndex), ...
                    find(invalid), char(method), 'extrap');
                status = "interpolated_" + method;
            end
        case "previous"
            x = fillPrevious(original);
            status = "filled_previous";
        otherwise
            error("不支持的缺失处理方法：%s", method);
    end

    x = x(isfinite(x));
end


function x = fillPrevious(x)
    validIndex = find(isfinite(x), 1, 'first');

    if isempty(validIndex)
        x = [];
        return;
    end

    x(1:validIndex - 1) = x(validIndex);

    for i = validIndex + 1:numel(x)
        if ~isfinite(x(i))
            x(i) = x(i - 1);
        end
    end
end


function names = expandMetricNames(metrics, quantiles)
    names = strings(0, 1);

    for imetric = 1:numel(metrics)
        metric = metrics(imetric);

        if metric == "quantiles"
            for iq = 1:numel(quantiles)
                names(end + 1) = "quantile_" + ...
                    sprintf('%03d', round(quantiles(iq) * 1000)); %#ok<AGROW>
            end
        else
            names(end + 1) = metric; %#ok<AGROW>
        end
    end

    names = names(:)';
end


function values = calculateMetrics(x, sampleRate, options, metricNames)
    values = NaN(1, numel(metricNames));
    varianceFlag = double(lower(string(options.varianceNormalization)) == ...
        "population");
    sampleVariance = var(x, varianceFlag);
    sampleStd = sqrt(sampleVariance);
    centered = x - mean(x);
    secondMoment = mean(centered .^ 2);
    dx = diff(x);
    ddx = diff(dx);

    for imetric = 1:numel(metricNames)
        metric = metricNames(imetric);

        switch metric
            case "mean"
                value = mean(x);
            case "median"
                value = median(x);
            case "min"
                value = min(x);
            case "max"
                value = max(x);
            case {"range", "peak_to_peak"}
                value = max(x) - min(x);
            case "trimmed_mean"
                value = trimmedMean(x, options.trimPercent);
            case "variance"
                value = sampleVariance;
            case "std"
                value = sampleStd;
            case "mad"
                if options.madMethod == "mean"
                    value = mean(abs(x - mean(x)));
                else
                    value = median(abs(x - median(x)));
                end
            case "iqr"
                value = percentile(x, 0.75, options.quantileMethod) - ...
                    percentile(x, 0.25, options.quantileMethod);
            case "rms"
                value = sqrt(mean(x .^ 2));
            case "coefficient_of_variation"
                denominator = abs(mean(x));
                value = sampleStd / denominator;

                if denominator == 0
                    value = NaN;
                end
            case "energy"
                value = sum(x .^ 2);
            case "sum_abs"
                value = sum(abs(x));
            case "skewness"
                if secondMoment > 0
                    value = mean(centered .^ 3) / secondMoment ^ 1.5;
                    if options.shapeBiasCorrection == "bias_corrected" && ...
                            numel(x) > 2
                        n = numel(x);
                        value = sqrt(n * (n - 1)) / (n - 2) * value;
                    end
                else
                    value = NaN;
                end
            case "kurtosis"
                if secondMoment > 0
                    value = mean(centered .^ 4) / secondMoment ^ 2;
                    if options.shapeBiasCorrection == "bias_corrected" && ...
                            numel(x) > 3
                        n = numel(x);
                        value = ((n - 1) / ((n - 2) * (n - 3))) * ...
                            ((n + 1) * (value - 3) + 6) + 3;
                    end
                else
                    value = NaN;
                end
            case "mean_abs_diff"
                value = mean(abs(dx));
            case "line_length"
                value = sum(abs(dx));

                if options.lineLengthNormalization == "per_sample"
                    value = value / max(numel(dx), 1);
                elseif options.lineLengthNormalization == "per_second"
                    value = value / max(numel(dx) / sampleRate, eps);
                end
            case "zero_cross_rate"
                z = x;
                if options.zeroCrossReference == "mean"
                    z = z - mean(z);
                elseif options.zeroCrossReference == "median"
                    z = z - median(z);
                end

                threshold = options.zeroCrossThreshold;
                signCode = zeros(size(z));
                signCode(z > threshold) = 1;
                signCode(z < -threshold) = -1;
                signCode = signCode(signCode ~= 0);
                crossingCount = sum(signCode(1:end - 1) ~= signCode(2:end));

                if options.zeroCrossNormalization == "per_second"
                    value = crossingCount / max((numel(x) - 1) / sampleRate, eps);
                else
                    value = crossingCount / max(numel(x) - 1, 1);
                end
            case "hjorth_activity"
                value = sampleVariance;
            case "hjorth_mobility"
                value = sqrt(var(dx, varianceFlag) / sampleVariance);
            case "hjorth_complexity"
                mobility = sqrt(var(dx, varianceFlag) / sampleVariance);
                derivativeMobility = sqrt(var(ddx, varianceFlag) / ...
                    var(dx, varianceFlag));
                value = derivativeMobility / mobility;
            otherwise
                if startsWith(metric, "quantile_")
                    probability = str2double(extractAfter(metric, ...
                        "quantile_")) / 1000;
                    value = percentile(x, probability, options.quantileMethod);
                else
                    error("未实现的指标：%s", metric);
                end
        end

        if ~isfinite(value)
            value = NaN;
        end

        values(imetric) = value;
    end
end


function value = percentile(x, probability, method)
    x = sort(x(:));
    position = 1 + (numel(x) - 1) * probability;
    lowerIndex = floor(position);
    upperIndex = ceil(position);
    switch string(method)
        case "nearest"
            value = x(round(position));
        case "lower"
            value = x(lowerIndex);
        case "higher"
            value = x(upperIndex);
        case "midpoint"
            value = (x(lowerIndex) + x(upperIndex)) / 2;
        otherwise
            if lowerIndex == upperIndex
                value = x(lowerIndex);
            else
                fraction = position - lowerIndex;
                value = x(lowerIndex) * (1 - fraction) + ...
                    x(upperIndex) * fraction;
            end
    end
end


function value = trimmedMean(x, trimPercent)
    sorted = sort(x(:));
    trimCount = floor(numel(sorted) * trimPercent / 100);
    kept = sorted(trimCount + 1:numel(sorted) - trimCount);
    value = mean(kept);
end

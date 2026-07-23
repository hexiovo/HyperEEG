function [scalarTable, seriesTable, details, info] = ...
        NonlinearStatistics(data, sampleRate, options)
%NONLINEARSTATISTICS 按通道计算熵、分形与非线性动力学指标。
%   标量输出为宽表；DFA、多尺度熵、相关维数和Lyapunov拟合曲线以
%   long-format序列表返回。RQA递归矩阵默认仅保存在details/MAT中。

    if ~isnumeric(data) || ~ismatrix(data) || isempty(data) || ~isreal(data)
        error("data必须为非空的通道×采样点实数矩阵。");
    end

    if ~isnumeric(sampleRate) || ~isscalar(sampleRate) || ...
            ~isfinite(sampleRate) || sampleRate <= 0
        error("sampleRate必须为正数。");
    end

    if isfield(options, 'nonlinear') && isfield(options, 'missing')
        nonlinear = options.nonlinear;
        missing = options.missing;
    else
        if ~isfield(options, 'enabled')
            options.enabled = true;
        end

        validated = HyperEEG.MultiCH.main.StatisticsOptions(struct( ...
            'inputDir', string(pwd), 'outputDir', string(pwd), ...
            'timeDomain', struct('enabled', false), ...
            'nonlinear', options));
        nonlinear = validated.nonlinear;
        missing = validated.missing;
    end

    scalarNames = scalarMetricNames(nonlinear.metrics);
    nChannel = size(data, 1);
    nTotal = size(data, 2);
    scalarValues = NaN(nChannel, numel(scalarNames));
    nValid = zeros(nChannel, 1);
    missingFraction = zeros(nChannel, 1);
    status = strings(nChannel, 1);
    details = cell(nChannel, 1);
    seriesTable = emptySeriesTable();

    for ichannel = 1:nChannel
        original = double(data(ichannel, :));
        missingFraction(ichannel) = mean(~isfinite(original));
        [x, status(ichannel)] = prepareValues(original, missing, ...
            missingFraction(ichannel));
        nValid(ichannel) = numel(x);

        if numel(x) < max(missing.minimumValidSamples, nonlinear.minimumSamples) || ...
                status(ichannel) == "rejected"
            status(ichannel) = "insufficient_or_rejected";
            details{ichannel} = struct('status', status(ichannel));
            continue;
        end

        [x, effectiveSampleRate] = limitSamples( ...
            x, nonlinear.maxSamples, sampleRate);
        [values, channelSeries, channelDetails] = calculateChannel( ...
            x, effectiveSampleRate, nonlinear, scalarNames, ichannel);
        scalarValues(ichannel, :) = values;
        seriesTable = [seriesTable; channelSeries]; %#ok<AGROW>
        channelDetails.originalValidSamples = nValid(ichannel);
        channelDetails.computationSamples = numel(x);
        channelDetails.effectiveSampleRate = effectiveSampleRate;
        details{ichannel} = channelDetails;
    end

    scalarTable = table((1:nChannel)', repmat(nTotal, nChannel, 1), ...
        nValid, missingFraction, status, ...
        'VariableNames', {'channel_index', 'n_total', 'n_valid', ...
        'missing_fraction', 'missing_status'});

    for iname = 1:numel(scalarNames)
        scalarTable.(scalarNames(iname)) = scalarValues(:, iname);
    end

    info.sampleRate = sampleRate;
    info.channelCount = nChannel;
    info.sampleCount = nTotal;
    info.scalarMetrics = scalarNames;
    info.seriesMetrics = unique(seriesTable.metric, 'stable')';
    info.options = nonlinear;
end


function [values, series, details] = calculateChannel( ...
        x, sampleRate, options, scalarNames, channelIndex)
    metrics = options.metrics;
    values = NaN(1, numel(scalarNames));
    scalar = struct();
    series = emptySeriesTable();
    details = struct();
    standardized = zscoreSafe(x);
    switch options.entropy.standardization
        case "zscore"
            entropySignal = standardized;
        case "demean"
            entropySignal = x - mean(x);
        otherwise
            entropySignal = x;
    end

    if ismember("spectral_entropy", metrics)
        [scalar.normalized_spectral_entropy, psdInfo] = ...
            spectralEntropy(x, sampleRate, options.spectral);
        details.spectralEntropy = psdInfo;
    end

    if ismember("differential_entropy", metrics)
        scalar.differential_entropy = differentialEntropy(x, ...
            options.differential);
    end

    tolerance = resolveTolerance(entropySignal, options.entropy.r, ...
        options.entropy.rMode);

    if ismember("sample_entropy", metrics)
        scalar.sample_entropy = sampleEntropy(entropySignal, ...
            options.entropy.m, tolerance, options.entropy.distance);
    end

    if ismember("approximate_entropy", metrics)
        scalar.approximate_entropy = approximateEntropy(entropySignal, ...
            options.entropy.m, tolerance, options.entropy.distance);
    end

    if ismember("fuzzy_entropy", metrics)
        scalar.fuzzy_entropy = fuzzyEntropy(entropySignal, ...
            options.entropy.m, tolerance, options.entropy.fuzzyPower, ...
            options.entropy.distance);
    end

    if ismember("permutation_entropy", metrics)
        scalar.permutation_entropy = permutationEntropy(x, ...
            options.permutation.dimension, options.permutation.delay, ...
            options.permutation.normalized);
    end

    if ismember("svd_entropy", metrics)
        scalar.svd_entropy = svdEntropy(standardized, ...
            options.svd.dimension, options.svd.delay, options.svd.normalized);
    end

    if ismember("lempel_ziv", metrics)
        binary = symbolizeBinary(x, options.lempelZiv.binarization);
        [scalar.lz_complexity, scalar.lz_complexity_raw] = ...
            lempelZiv(binary, options.lempelZiv.normalized);
    end

    if ismember("hurst", metrics)
        [scalar.hurst_exponent, scalar.hurst_fit_r2] = ...
            hurstExponent(x, options.hurst);
    end

    if ismember("dfa", metrics)
        [scalar.dfa_alpha, scalar.dfa_fit_r2, scale, fluctuation] = ...
            dfa(x, options.dfa);
        series = [series; makeSeries(channelIndex, "dfa", "scale_samples", ...
            scale, "fluctuation", fluctuation)]; %#ok<AGROW,MSNU>
        details.dfa.scale = scale;
        details.dfa.fluctuation = fluctuation;
    end

    if ismember("higuchi_fd", metrics)
        scalar.higuchi_fd = higuchiFD(x, options.fractal.higuchiKmax);
    end

    if ismember("petrosian_fd", metrics)
        scalar.petrosian_fd = petrosianFD(x);
    end

    if ismember("katz_fd", metrics)
        scalar.katz_fd = katzFD(x);
    end

    if ismember("multiscale_entropy", metrics)
        scales = 1:options.multiscale.maxScale;
        entropyValues = NaN(size(scales));

        for iscale = 1:numel(scales)
            coarse = coarseGrain(entropySignal, scales(iscale));

            if numel(coarse) >= options.entropy.m + 2
                entropyValues(iscale) = sampleEntropy(coarse, ...
                    options.entropy.m, tolerance, options.entropy.distance);
            end
        end

        scalar.mse_mean = mean(entropyValues, 'omitnan');
        scalar.mse_complexity_index = sum(entropyValues, 'omitnan');
        series = [series; makeSeries(channelIndex, "multiscale_entropy", ...
            "scale", scales, "sample_entropy", entropyValues)]; %#ok<AGROW,MSNU>
        details.multiscaleEntropy.scale = scales;
        details.multiscaleEntropy.value = entropyValues;
    end

    if ismember("correlation_dimension", metrics)
        [scalar.correlation_dimension, scalar.correlation_dimension_fit_r2, ...
            radius, correlationSum] = correlationDimension( ...
            standardized, options.correlationDimension);
        series = [series; makeSeries(channelIndex, "correlation_dimension", ...
            "radius", radius, "correlation_sum", correlationSum)]; %#ok<AGROW,MSNU>
        details.correlationDimension.radius = radius;
        details.correlationDimension.correlationSum = correlationSum;
    end

    if ismember("largest_lyapunov", metrics)
        [scalar.largest_lyapunov_exponent, scalar.lyapunov_fit_r2, ...
            lag, divergence] = largestLyapunov(standardized, sampleRate, ...
            options.lyapunov);
        series = [series; makeSeries(channelIndex, "largest_lyapunov", ...
            "lag_s", lag, "mean_log_divergence", divergence)]; %#ok<AGROW,MSNU>
        details.lyapunov.lag_s = lag;
        details.lyapunov.meanLogDivergence = divergence;
    end

    if ismember("rqa", metrics)
        [rqaScalar, recurrenceMatrix, rqaDetails] = rqa( ...
            standardized, options.rqa);
        rqaNames = fieldnames(rqaScalar);

        for iname = 1:numel(rqaNames)
            scalar.(rqaNames{iname}) = rqaScalar.(rqaNames{iname});
        end

        details.rqa = rqaDetails;

        if options.rqa.storeMatrixInMat || ...
                (options.rqa.exportMatrixToExcel && ...
                options.rqa.matrixExcelMode == "dense")
            details.rqa.recurrenceMatrix = recurrenceMatrix;
        end

        if options.rqa.exportMatrixToExcel && ...
                options.rqa.matrixExcelMode == "coordinates"
            [rowIndex, columnIndex] = find(recurrenceMatrix);
            matrixSeries = table(repmat(channelIndex, numel(rowIndex), 1), ...
                repmat("rqa_recurrence", numel(rowIndex), 1), ...
                repmat("row_index", numel(rowIndex), 1), double(rowIndex), ...
                repmat("column_index", numel(rowIndex), 1), ...
                double(columnIndex), ...
                'VariableNames', {'channel_index', 'metric', 'index_name', ...
                'index_value', 'value_name', 'value'});
            series = [series; matrixSeries]; %#ok<AGROW,MSNU>
        end
    end

    scalarFields = string(fieldnames(scalar));

    for iname = 1:numel(scalarNames)
        match = find(scalarFields == scalarNames(iname), 1);

        if ~isempty(match)
            values(iname) = scalar.(scalarFields(match));
        end
    end

    values(~isfinite(values)) = NaN;
end


function names = scalarMetricNames(metrics)
    names = strings(0, 1);
    mapping = { ...
        "spectral_entropy", "normalized_spectral_entropy"; ...
        "differential_entropy", "differential_entropy"; ...
        "sample_entropy", "sample_entropy"; ...
        "approximate_entropy", "approximate_entropy"; ...
        "fuzzy_entropy", "fuzzy_entropy"; ...
        "permutation_entropy", "permutation_entropy"; ...
        "svd_entropy", "svd_entropy"; ...
        "lempel_ziv", ["lz_complexity", "lz_complexity_raw"]; ...
        "hurst", ["hurst_exponent", "hurst_fit_r2"]; ...
        "dfa", ["dfa_alpha", "dfa_fit_r2"]; ...
        "higuchi_fd", "higuchi_fd"; ...
        "petrosian_fd", "petrosian_fd"; ...
        "katz_fd", "katz_fd"; ...
        "multiscale_entropy", ["mse_mean", "mse_complexity_index"]; ...
        "correlation_dimension", ["correlation_dimension", ...
            "correlation_dimension_fit_r2"]; ...
        "largest_lyapunov", ["largest_lyapunov_exponent", ...
            "lyapunov_fit_r2"]; ...
        "rqa", ["rqa_rr", "rqa_det", "rqa_lmax", "rqa_lmean", ...
            "rqa_ent", "rqa_ratio", "rqa_div", "rqa_lam", ...
            "rqa_tt", "rqa_vmax", "rqa_art", "rqa_trend"]};

    for i = 1:size(mapping, 1)
        if ismember(mapping{i, 1}, metrics)
            names = [names; mapping{i, 2}(:)]; %#ok<AGROW>
        end
    end

    names = names(:)';
end


function [x, status] = prepareValues(original, options, missingFraction)
    method = lower(string(options.method));
    invalid = ~isfinite(original);

    if method == "reject_file" && missingFraction > options.maxFraction
        error('HyperEEG:Statistics:RejectFile', ...
            '文件缺失比例超过阈值（%.3f > %.3f）。', ...
            missingFraction, options.maxFraction);
    end

    if method == "reject_channel" && missingFraction > options.maxFraction
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
            valid = find(~invalid);

            if numel(valid) < 2
                x = original(~invalid);
                status = "insufficient_or_rejected";
            else
                x = original;
                x(invalid) = interp1(valid, original(valid), find(invalid), ...
                    char(method), 'extrap');
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
    first = find(isfinite(x), 1);

    if isempty(first)
        x = [];
        return;
    end

    x(1:first - 1) = x(first);

    for i = first + 1:numel(x)
        if ~isfinite(x(i)), x(i) = x(i - 1); end
    end
end


function [x, effectiveSampleRate] = limitSamples(x, maximum, sampleRate)
    originalCount = numel(x);
    effectiveSampleRate = sampleRate;

    if numel(x) > maximum
        index = unique(round(linspace(1, numel(x), maximum)));
        x = x(index);
        effectiveSampleRate = sampleRate * (numel(x) - 1) / ...
            max(originalCount - 1, 1);
    end
end


function z = zscoreSafe(x)
    scale = std(x, 0);

    if scale > 0
        z = (x - mean(x)) / scale;
    else
        z = x - mean(x);
    end
end


function tolerance = resolveTolerance(x, r, mode)
    if lower(string(mode)) == "std"
        tolerance = r * std(x, 0);
    else
        tolerance = r;
    end

    tolerance = max(tolerance, eps);
end


function [value, info] = spectralEntropy(x, sampleRate, options)
    windowSamples = max(8, round(options.windowSeconds * sampleRate));
    windowSamples = min(windowSamples, numel(x));
    nfft = max(options.nfft, 2 ^ nextpow2(windowSamples));
    if options.method == "periodogram"
        nfft = max(nfft, 2 ^ nextpow2(numel(x)));
        overlapSamples = 0;
        [powerValue, frequencyHz] = periodogram(x, hamming(numel(x)), ...
            nfft, sampleRate, 'psd');
    else
        overlapSamples = min(windowSamples - 1, ...
            round(windowSamples * options.overlap));
        [powerValue, frequencyHz] = pwelch(x, hamming(windowSamples), ...
            overlapSamples, nfft, sampleRate, 'psd');
    end
    selected = frequencyHz >= options.frequencyRangeHz(1) & ...
        frequencyHz <= min(options.frequencyRangeHz(2), sampleRate / 2);
    probability = powerValue(selected);
    probability = probability / sum(probability);
    probability = probability(probability > 0);
    value = -sum(probability .* log2(probability));

    if options.normalized && numel(probability) > 1
        value = value / log2(numel(probability));
    end

    info.method = options.method;
    info.frequencyRangeHz = options.frequencyRangeHz;
    info.windowSamples = windowSamples;
    info.overlapSamples = overlapSamples;
    info.nfft = nfft;
end


function value = differentialEntropy(x, options)
    if options.method == "histogram"
        [count, edges] = histcounts(x, options.histogramBins, ...
            'Normalization', 'probability');
        probability = count(count > 0);
        if isempty(probability) || numel(edges) < 2 || edges(2) <= edges(1)
            value = NaN;
        else
            value = -sum(probability .* log(probability)) + ...
                log(edges(2) - edges(1));
        end
    else
        varianceValue = var(x, 1);
        value = 0.5 * log(2 * pi * exp(1) * varianceValue);
    end
end


function value = sampleEntropy(x, m, r, distanceMethod)
    countM = templateMatches(x, m, r, false, distanceMethod);
    countM1 = templateMatches(x, m + 1, r, false, distanceMethod);

    if countM == 0 || countM1 == 0
        value = NaN;
    else
        value = -log(countM1 / countM);
    end
end


function value = approximateEntropy(x, m, r, distanceMethod)
    value = phi(x, m, r, distanceMethod) - ...
        phi(x, m + 1, r, distanceMethod);
end


function result = phi(x, m, r, distanceMethod)
    embedded = embedConsecutive(x, m);
    n = size(embedded, 1);
    probabilities = zeros(n, 1);

    for i = 1:n
        probabilities(i) = mean(templateDistance(embedded, ...
            embedded(i, :), distanceMethod) <= r);
    end

    result = mean(log(max(probabilities, realmin)));
end


function count = templateMatches(x, m, r, includeSelf, distanceMethod)
    embedded = embedConsecutive(x, m);
    n = size(embedded, 1);
    count = 0;

    for i = 1:n
        first = i + double(~includeSelf);

        if first <= n
            count = count + sum(templateDistance(embedded(first:n, :), ...
                embedded(i, :), distanceMethod) <= r);
        end
    end
end


function value = fuzzyEntropy(x, m, r, powerValue, distanceMethod)
    phiM = fuzzyPhi(x, m, r, powerValue, distanceMethod);
    phiM1 = fuzzyPhi(x, m + 1, r, powerValue, distanceMethod);
    value = -log(phiM1 / phiM);
end


function value = fuzzyPhi(x, m, r, powerValue, distanceMethod)
    embedded = embedConsecutive(x, m);
    embedded = embedded - mean(embedded, 2);
    n = size(embedded, 1);
    total = 0;
    pairs = 0;

    for i = 1:n - 1
        distance = templateDistance(embedded(i + 1:n, :), ...
            embedded(i, :), distanceMethod);
        total = total + sum(exp(-(distance .^ powerValue) / r));
        pairs = pairs + numel(distance);
    end

    value = total / max(pairs, 1);
end


function distance = templateDistance(points, reference, method)
    difference = points - reference;
    if method == "euclidean"
        distance = sqrt(sum(difference .^ 2, 2));
    else
        distance = max(abs(difference), [], 2);
    end
end


function embedded = embedConsecutive(x, dimension)
    n = numel(x) - dimension + 1;

    if n < 1
        embedded = zeros(0, dimension);
        return;
    end

    embedded = zeros(n, dimension);

    for j = 1:dimension
        embedded(:, j) = x(j:j + n - 1);
    end
end


function embedded = delayEmbed(x, dimension, delay)
    n = numel(x) - (dimension - 1) * delay;

    if n < 1
        embedded = zeros(0, dimension);
        return;
    end

    embedded = zeros(n, dimension);

    for j = 1:dimension
        startIndex = 1 + (j - 1) * delay;
        embedded(:, j) = x(startIndex:startIndex + n - 1);
    end
end


function value = permutationEntropy(x, dimension, delay, normalized)
    embedded = delayEmbed(x, dimension, delay);
    patterns = zeros(size(embedded));

    for i = 1:size(embedded, 1)
        [~, patterns(i, :)] = sort(embedded(i, :), 'ascend');
    end

    [~, ~, group] = unique(patterns, 'rows');
    counts = accumarray(group, 1);
    probability = counts / sum(counts);
    value = -sum(probability .* log2(probability));

    if normalized
        value = value / log2(factorial(dimension));
    end
end


function value = svdEntropy(x, dimension, delay, normalized)
    embedded = delayEmbed(x, dimension, delay);
    singularValues = svd(embedded, 'econ');
    probability = singularValues / sum(singularValues);
    probability = probability(probability > 0);
    value = -sum(probability .* log2(probability));

    if normalized && numel(probability) > 1
        value = value / log2(numel(probability));
    end
end


function binary = symbolizeBinary(x, method)
    switch lower(string(method))
        case "median"
            threshold = median(x);
        case "mean"
            threshold = mean(x);
        case "zero"
            threshold = 0;
        otherwise
            error("不支持的Lempel-Ziv二值化方法：%s", method);
    end

    binary = x >= threshold;
end


function [normalizedValue, rawValue] = lempelZiv(sequence, normalized)
    textValue = char('0' + sequence(:)');
    n = numel(textValue);

    if n < 2
        rawValue = n;
        normalizedValue = n;
        return;
    end

    i = 1; k = 1; l = 2; kMax = 1; complexity = 1;

    while true
        if l + k > n || i + k > n
            complexity = complexity + 1;
            break;
        end

        if textValue(i + k - 1) == textValue(l + k - 1)
            k = k + 1;
            if l + k > n
                complexity = complexity + 1;
                break;
            end
        else
            kMax = max(kMax, k);
            i = i + 1;

            if i == l
                complexity = complexity + 1;
                l = l + kMax;

                if l >= n, break; end
                i = 1; k = 1; kMax = 1;
            else
                k = 1;
            end
        end
    end

    rawValue = complexity;
    normalizedValue = rawValue;

    if normalized && n > 1
        normalizedValue = rawValue * log2(n) / n;
    end
end


function [hurst, fitR2] = hurstExponent(x, options)
    scale = unique(round(logspace(log10(options.scaleMin), ...
        log10(min(options.scaleMax, floor(numel(x) / 2))), options.nScales)));
    rs = NaN(size(scale));

    for iscale = 1:numel(scale)
        blockSize = scale(iscale);
        nBlock = floor(numel(x) / blockSize);
        values = NaN(nBlock, 1);

        for iblock = 1:nBlock
            block = x((iblock - 1) * blockSize + (1:blockSize));
            cumulative = cumsum(block - mean(block));
            denominator = std(block, 0);

            if denominator > 0
                values(iblock) = (max(cumulative) - min(cumulative)) / denominator;
            end
        end

        rs(iscale) = mean(values, 'omitnan');
    end

    [hurst, fitR2] = logFit(scale, rs);
end


function [alpha, fitR2, scale, fluctuation] = dfa(x, options)
    profile = cumsum(x - mean(x));
    scale = unique(round(logspace(log10(options.scaleMin), ...
        log10(min(options.scaleMax, floor(numel(x) / 4))), options.nScales)));
    fluctuation = NaN(size(scale));

    for iscale = 1:numel(scale)
        blockSize = scale(iscale);
        nBlock = floor(numel(profile) / blockSize);
        residualPower = zeros(nBlock, 1);

        for iblock = 1:nBlock
            index = (iblock - 1) * blockSize + (1:blockSize);
            coefficient = polyfit((1:blockSize)', profile(index)', options.order);
            trend = polyval(coefficient, (1:blockSize)');
            residualPower(iblock) = mean((profile(index)' - trend) .^ 2);
        end

        fluctuation(iscale) = sqrt(mean(residualPower, 'omitnan'));
    end

    [alpha, fitR2] = logFit(scale, fluctuation);
end


function [slope, fitR2] = logFit(x, y)
    valid = isfinite(x) & isfinite(y) & x > 0 & y > 0;

    if sum(valid) < 3
        slope = NaN; fitR2 = NaN; return;
    end

    predictor = log(double(x(valid(:))));
    response = log(double(y(valid(:))));
    coefficient = polyfit(predictor, response, 1);
    fitted = polyval(coefficient, predictor);
    slope = coefficient(1);
    fitR2 = coefficientOfDetermination(response, fitted);
end


function value = higuchiFD(x, kmax)
    n = numel(x);
    lengthValue = NaN(kmax, 1);

    for k = 1:kmax
        subLength = zeros(k, 1);

        for m = 1:k
            count = floor((n - m) / k);

            if count < 1, continue; end
            index = m + (0:count) * k;
            normalization = (n - 1) / (count * k);
            subLength(m) = sum(abs(diff(x(index)))) * normalization / k;
        end

        lengthValue(k) = mean(subLength(subLength > 0));
    end

    valid = isfinite(lengthValue) & lengthValue > 0;

    if sum(valid) < 2
        value = NaN;
    else
        predictor = log(1 ./ (1:kmax))';
        coefficient = polyfit(predictor(valid), log(lengthValue(valid)), 1);
        value = coefficient(1);
    end
end


function value = petrosianFD(x)
    n = numel(x);
    derivative = diff(x);
    signChanges = sum(derivative(1:end - 1) .* derivative(2:end) < 0);
    value = log10(n) / (log10(n) + log10(n / (n + 0.4 * signChanges)));
end


function value = katzFD(x)
    n = numel(x);
    time = (0:n - 1) / max(n - 1, 1);
    amplitude = zscoreSafe(x);
    step = hypot(diff(time), diff(amplitude));
    totalLength = sum(step);
    distance = max(hypot(time - time(1), amplitude - amplitude(1)));
    value = log10(n - 1) / (log10(distance / totalLength) + log10(n - 1));
end


function coarse = coarseGrain(x, scale)
    nBlock = floor(numel(x) / scale);
    coarse = mean(reshape(x(1:nBlock * scale), scale, nBlock), 1);
end


function [dimensionValue, fitR2, radius, correlationSum] = ...
        correlationDimension(x, options)
    embedded = delayEmbed(x, options.dimension, options.delay);
    embedded = limitRows(embedded, options.maxPoints);
    distance = pairDistances(embedded, options.theilerWindow);
    distance = distance(isfinite(distance) & distance > 0);

    if numel(distance) < 20
        dimensionValue = NaN; fitR2 = NaN; radius = []; correlationSum = [];
        return;
    end

    bounds = percentileLocal(distance, options.radiusPercentiles / 100);
    radius = logspace(log10(bounds(1)), log10(bounds(2)), options.nRadii);
    correlationSum = arrayfun(@(r) mean(distance <= r), radius);
    [dimensionValue, fitR2] = logFit(radius, correlationSum);
end


function [exponent, fitR2, lagSeconds, divergence] = ...
        largestLyapunov(x, sampleRate, options)
    embedded = delayEmbed(x, options.dimension, options.delay);
    embedded = limitRows(embedded, options.maxPoints);
    n = size(embedded, 1);
    neighbor = zeros(n, 1);

    for i = 1:n
        distance = sqrt(sum((embedded - embedded(i, :)) .^ 2, 2));
        distance(abs((1:n)' - i) <= options.theilerWindow) = inf;
        [~, neighbor(i)] = min(distance);
    end

    maxStep = min(options.maxSteps, floor(n / 4));
    divergence = NaN(1, maxStep + 1);

    for k = 0:maxStep
        valid = (1:n)' + k <= n & neighbor + k <= n;
        current = find(valid);
        distance = sqrt(sum((embedded(current + k, :) - ...
            embedded(neighbor(current) + k, :)) .^ 2, 2));
        distance = distance(distance > 0 & isfinite(distance));
        divergence(k + 1) = mean(log(distance), 'omitnan');
    end

    lagSeconds = (0:maxStep) / sampleRate;
    valid = isfinite(divergence);

    if sum(valid) < 3
        exponent = NaN; fitR2 = NaN;
    else
        coefficient = polyfit(lagSeconds(valid), divergence(valid), 1);
        fitted = polyval(coefficient, lagSeconds(valid));
        exponent = coefficient(1);
        fitR2 = coefficientOfDetermination(divergence(valid)', fitted');
    end
end


function [scalar, recurrence, details] = rqa(x, options)
    embedded = delayEmbed(x, options.embeddingDimension, options.delay);
    embedded = limitRows(embedded, options.maxPoints);
    n = size(embedded, 1);
    distance = zeros(n, n);

    for i = 1:n
        difference = embedded - embedded(i, :);
        if options.distance == "chebyshev"
            distance(i, :) = max(abs(difference), [], 2);
        else
            distance(i, :) = sqrt(sum(difference .^ 2, 2));
        end
    end

    if options.thresholdMode == "target_rr"
        candidate = distance(triu(true(n), options.theilerWindow + 1));
        epsilon = percentileLocal(candidate, options.targetRR);
    else
        epsilon = options.epsilon;
    end

    recurrence = distance <= epsilon;

    for offset = -options.theilerWindow:options.theilerWindow
        recurrence = setDiagonal(recurrence, offset, false);
    end

    recurrentPoints = nnz(recurrence);
    possiblePoints = n ^ 2 - sum(arrayfun(@(offset) ...
        n - abs(offset), -options.theilerWindow:options.theilerWindow));
    rr = recurrentPoints / max(possiblePoints, 1);
    diagonalLength = collectDiagonalLines(recurrence, options.minDiagonalLine);
    verticalLength = collectVerticalLines(recurrence, options.minVerticalLine);
    diagonalPoints = sum(diagonalLength);
    verticalPoints = sum(verticalLength);
    lmax = maxOrNaN(diagonalLength);
    lmean = mean(diagonalLength, 'omitnan');
    ent = lineEntropy(diagonalLength);
    det = diagonalPoints / max(recurrentPoints, 1);
    lam = verticalPoints / max(recurrentPoints, 1);
    tt = mean(verticalLength, 'omitnan');
    vmax = maxOrNaN(verticalLength);
    art = averageRecurrenceTime(recurrence);
    trend = recurrenceTrend(recurrence, options.theilerWindow);
    scalar.rqa_rr = rr;
    scalar.rqa_det = det;
    scalar.rqa_lmax = lmax;
    scalar.rqa_lmean = lmean;
    scalar.rqa_ent = ent;
    scalar.rqa_ratio = det / max(rr, eps);
    scalar.rqa_div = 1 / lmax;
    scalar.rqa_lam = lam;
    scalar.rqa_tt = tt;
    scalar.rqa_vmax = vmax;
    scalar.rqa_art = art;
    scalar.rqa_trend = trend;
    details.embeddingPoints = n;
    details.epsilon = epsilon;
    details.thresholdMode = options.thresholdMode;
    details.distance = options.distance;
    details.recurrentPoints = recurrentPoints;
end


function matrix = setDiagonal(matrix, offset, value)
    n = size(matrix, 1);
    if offset >= 0
        index = sub2ind([n, n], 1:n - offset, 1 + offset:n);
    else
        index = sub2ind([n, n], 1 - offset:n, 1:n + offset);
    end
    matrix(index) = value;
end


function lengths = collectDiagonalLines(matrix, minimum)
    n = size(matrix, 1);
    lengths = [];

    for offset = -(n - 1):(n - 1)
        lengths = [lengths, runLengths(diag(matrix, offset), minimum)]; %#ok<AGROW>
    end
end


function lengths = collectVerticalLines(matrix, minimum)
    lengths = [];

    for column = 1:size(matrix, 2)
        lengths = [lengths, runLengths(matrix(:, column), minimum)]; %#ok<AGROW>
    end
end


function lengths = runLengths(binary, minimum)
    padded = [false; logical(binary(:)); false];
    difference = diff(padded);
    lengths = find(difference == -1) - find(difference == 1);
    lengths = lengths(lengths >= minimum)';
end


function value = lineEntropy(lengths)
    if isempty(lengths), value = NaN; return; end
    [~, ~, group] = unique(lengths);
    count = accumarray(group(:), 1);
    probability = count / sum(count);
    value = -sum(probability .* log(probability));
end


function value = averageRecurrenceTime(matrix)
    gaps = [];

    for column = 1:size(matrix, 2)
        index = find(matrix(:, column));
        gaps = [gaps; diff(index)]; %#ok<AGROW>
    end

    value = mean(gaps, 'omitnan');
end


function value = recurrenceTrend(matrix, theiler)
    n = size(matrix, 1);
    offset = (theiler + 1:n - 1)';
    rate = NaN(size(offset));

    for i = 1:numel(offset)
        diagonal = diag(matrix, offset(i));
        rate(i) = mean(diagonal);
    end

    valid = isfinite(rate);

    if sum(valid) < 3
        value = NaN;
    else
        coefficient = polyfit(offset(valid) / n, rate(valid), 1);
        value = coefficient(1);
    end
end


function distance = pairDistances(points, theiler)
    n = size(points, 1);
    distance = [];

    for i = 1:n - 1
        first = i + theiler + 1;

        if first <= n
            current = sqrt(sum((points(first:n, :) - points(i, :)) .^ 2, 2));
            distance = [distance; current]; %#ok<AGROW>
        end
    end
end


function points = limitRows(points, maximum)
    if size(points, 1) > maximum
        index = unique(round(linspace(1, size(points, 1), maximum)));
        points = points(index, :);
    end
end


function result = percentileLocal(x, probabilities)
    x = sort(x(:));
    result = NaN(size(probabilities));

    for i = 1:numel(probabilities)
        p = probabilities(i);
        position = 1 + (numel(x) - 1) * p;
        lowerIndex = floor(position);
        upperIndex = ceil(position);

        if lowerIndex == upperIndex
            result(i) = x(lowerIndex);
        else
            fraction = position - lowerIndex;
            result(i) = x(lowerIndex) * (1 - fraction) + ...
                x(upperIndex) * fraction;
        end
    end
end


function value = coefficientOfDetermination(actual, fitted)
    residual = sum((actual - fitted) .^ 2);
    total = sum((actual - mean(actual)) .^ 2);
    value = 1 - residual / max(total, eps);
end


function value = maxOrNaN(x)
    if isempty(x), value = NaN; else, value = max(x); end
end


function tableValue = emptySeriesTable()
    tableValue = table(zeros(0, 1), strings(0, 1), strings(0, 1), ...
        zeros(0, 1), strings(0, 1), zeros(0, 1), ...
        'VariableNames', {'channel_index', 'metric', 'index_name', ...
        'index_value', 'value_name', 'value'});
end


function tableValue = makeSeries(channelIndex, metric, indexName, ...
        indexValue, valueName, value)
    n = numel(indexValue);
    tableValue = table(repmat(channelIndex, n, 1), repmat(string(metric), n, 1), ...
        repmat(string(indexName), n, 1), double(indexValue(:)), ...
        repmat(string(valueName), n, 1), double(value(:)), ...
        'VariableNames', {'channel_index', 'metric', 'index_name', ...
        'index_value', 'value_name', 'value'});
end

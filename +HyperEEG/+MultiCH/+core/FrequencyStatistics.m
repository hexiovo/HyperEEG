function [scalarTable, spectrumTable, peakTable, pairTable, details, info] = ...
        FrequencyStatistics(data, sampleRate, options, channelNames)
%FREQUENCYSTATISTICS 计算5.2频谱、频带、谱形、1/f与FAA指标。
%   标量结果按通道写宽表；完整PSD和周期峰以长表返回；FAA按电极对返回。

    if nargin < 4 || isempty(channelNames)
        channelNames = "Ch" + string((1:size(data, 1))');
    else
        channelNames = string(channelNames(:));
    end

    frequencyOptions = options.frequency;
    nChannel = size(data, 1);
    metricNames = scalarMetricNames(frequencyOptions);
    scalarValues = nan(nChannel, numel(metricNames));
    nOriginal = repmat(size(data, 2), nChannel, 1);
    nValid = zeros(nChannel, 1);
    missingFraction = zeros(nChannel, 1);
    effectiveDuration = zeros(nChannel, 1);
    status = strings(nChannel, 1);
    spectrumTable = emptySpectrumTable();
    peakTable = emptyPeakTable();
    details = cell(nChannel, 1);

    for channelIndex = 1:nChannel
        original = double(data(channelIndex, :));
        missingFraction(channelIndex) = mean(~isfinite(original));
        nValid(channelIndex) = sum(isfinite(original));
        effectiveDuration(channelIndex) = nValid(channelIndex) / sampleRate;
        [x, status(channelIndex)] = prepareValues( ...
            original, options, missingFraction(channelIndex));

        if isempty(x) || numel(x) < frequencyOptions.minimumSamples
            details{channelIndex} = struct('status', status(channelIndex));
            continue;
        end

        try
            [values, spectrum, peaks, detail] = calculateChannel( ...
                x, sampleRate, frequencyOptions, metricNames);
            scalarValues(channelIndex, :) = values;
            detail.status = status(channelIndex);
            details{channelIndex} = detail;

            if ismember("psd", frequencyOptions.metrics)
                spectrum.channel_index = repmat(channelIndex, ...
                    height(spectrum), 1);
                spectrum = movevars(spectrum, 'channel_index', ...
                    'Before', 1);
                spectrumTable = [spectrumTable; spectrum]; %#ok<AGROW>
            end

            if ~isempty(peaks)
                peaks.channel_index = repmat(channelIndex, height(peaks), 1);
                peaks = movevars(peaks, 'channel_index', 'Before', 1);
                peakTable = [peakTable; peaks]; %#ok<AGROW>
            end
        catch ME
            status(channelIndex) = "calculation_failed: " + string(ME.message);
            details{channelIndex} = struct('status', status(channelIndex));
        end
    end

    scalarTable = array2table(scalarValues, ...
        'VariableNames', cellstr(metricNames));
    scalarTable = addvars(scalarTable, (1:nChannel)', nOriginal, nValid, ...
        missingFraction, effectiveDuration, status, 'Before', 1, ...
        'NewVariableNames', {'channel_index', 'n_original', 'n_valid', ...
        'missing_fraction', 'effective_duration_s', 'status'});
    pairTable = calculateFAA(details, channelNames, frequencyOptions);

    info.sampleRateHz = sampleRate;
    info.channelCount = nChannel;
    info.metrics = frequencyOptions.metrics;
    info.bandNames = frequencyOptions.bands.names;
    info.bandRangesHz = frequencyOptions.bands.rangesHz;
    info.scalarColumns = metricNames;
    info.spectrumRows = height(spectrumTable);
    info.periodicPeakRows = height(peakTable);
    info.faaPairRows = height(pairTable);
end


function [values, spectrum, peakTable, detail] = calculateChannel( ...
        x, sampleRate, options, metricNames)
    [powerValue, frequency, welchInfo] = calculatePSD(x, sampleRate, options);
    powerDb = 10 * log10(max(powerValue, realmin));
    spectrum = table(frequency, powerValue, powerDb, ...
        'VariableNames', {'frequency_hz', 'power', 'power_db_hz'});

    values = nan(1, numel(metricNames));
    metricMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
    totalPower = integrateRange(frequency, powerValue, options.totalRangeHz);
    metricMap('total_power') = totalPower;
    bandPower = nan(numel(options.bands.names), 1);

    for iband = 1:numel(options.bands.names)
        bandName = validBandName(options.bands.names(iband));
        bandPower(iband) = integrateRange(frequency, powerValue, ...
            options.bands.rangesHz(iband, :));

        if ismember("absolute_power", options.metrics)
            metricMap(char("absolute_power_" + bandName)) = bandPower(iband);
        end

        if ismember("relative_power", options.metrics)
            metricMap(char("relative_power_" + bandName)) = ...
                safeDivide(bandPower(iband), totalPower);
        end

        if ismember("log_power", options.metrics)
            metricMap(char(logPowerName(options.logTransform, bandName))) = ...
                transformPower(bandPower(iband), options.logTransform);
        end
    end

    analysisMask = inRange(frequency, options.shape.frequencyRangeHz);
    fShape = frequency(analysisMask);
    pShape = powerValue(analysisMask);

    if ismember("spectral_shape", options.metrics) && ~isempty(fShape)
        [peakPower, peakIndex] = max(pShape);
        metricMap('peak_frequency_hz') = fShape(peakIndex);
        metricMap('peak_power') = peakPower;
        metricMap('spectral_centroid_hz') = weightedMean(fShape, pShape);
        metricMap('median_frequency_hz') = spectralQuantile(fShape, pShape, 0.5);
        centroid = metricMap('spectral_centroid_hz');
        metricMap('bandwidth_hz') = sqrt(safeDivide( ...
            sum(((fShape - centroid).^2) .* pShape), sum(pShape)));
    end

    if ismember("spectral_flatness", options.metrics) && ~isempty(pShape)
        metricMap('spectral_flatness') = exp(mean(log(max(pShape, ...
            realmin)))) / mean(pShape);
    end

    if ismember("spectral_edge", options.metrics)
        for iedge = 1:numel(options.shape.edgeFractions)
            fraction = options.shape.edgeFractions(iedge);
            name = sprintf('spectral_edge_%g_hz', round(fraction * 100));
            metricMap(name) = spectralQuantile(fShape, pShape, fraction);
        end
    end

    if ismember("individual_alpha_peak", options.metrics)
        alphaMask = inRange(frequency, options.shape.alphaPeakRangeHz);
        alphaFrequency = frequency(alphaMask);
        alphaPower = powerValue(alphaMask);
        if ~isempty(alphaPower)
            [alphaPeakPower, alphaIndex] = max(alphaPower);
            metricMap('individual_alpha_peak_hz') = alphaFrequency(alphaIndex);
            metricMap('individual_alpha_peak_power') = alphaPeakPower;
        end
    end

    peakTable = emptyPeakTableWithoutChannel();
    aperiodic = struct();
    if ismember("aperiodic", options.metrics)
        [aperiodic, peakTable] = fitAperiodic(frequency, powerValue, ...
            options.aperiodic);
        metricMap('aperiodic_exponent') = aperiodic.exponent;
        metricMap('aperiodic_offset') = aperiodic.offset;
        metricMap('aperiodic_fit_r2') = aperiodic.fitR2;
    end

    bandMap = containers.Map(cellstr(validBandName(options.bands.names)), ...
        num2cell(bandPower));
    if ismember("theta_beta_ratio", options.metrics)
        metricMap('theta_beta_ratio') = bandRatio(bandMap, "theta", "beta");
    end
    if ismember("alpha_theta_ratio", options.metrics)
        metricMap('alpha_theta_ratio') = bandRatio(bandMap, "alpha", "theta");
    end
    if ismember("high_low_ratio", options.metrics)
        numerator = bandValue(bandMap, "alpha") + bandValue(bandMap, "beta");
        denominator = bandValue(bandMap, "delta") + bandValue(bandMap, "theta");
        metricMap('alpha_beta_over_delta_theta') = ...
            safeDivide(numerator, denominator);
    end

    for imetric = 1:numel(metricNames)
        key = char(metricNames(imetric));
        if isKey(metricMap, key), values(imetric) = metricMap(key); end
    end

    detail.frequencyHz = frequency;
    detail.power = powerValue;
    detail.powerDbHz = powerDb;
    detail.welch = welchInfo;
    detail.totalRangeHz = options.totalRangeHz;
    detail.bandNames = options.bands.names;
    detail.bandRangesHz = options.bands.rangesHz;
    detail.bandPower = bandPower;
    detail.aperiodic = aperiodic;
    detail.periodicPeaks = peakTable;
end


function [powerValue, frequency, info] = calculatePSD(x, sampleRate, options)
    x = double(x(:));
    switch options.welch.detrend
        case "constant"
            x = detrend(x, 0);
        case "linear"
            x = detrend(x, 1);
    end

    windowSamples = min(numel(x), max(8, round( ...
        options.welch.windowSeconds * sampleRate)));
    overlapSamples = min(windowSamples - 1, floor( ...
        windowSamples * options.welch.overlap));
    nfft = max(options.welch.nfft, 2^nextpow2(windowSamples));
    window = hamming(windowSamples, 'periodic');
    [powerValue, frequency] = pwelch(x, window, overlapSamples, ...
        nfft, sampleRate, 'psd');
    keep = frequency <= sampleRate / 2;
    powerValue = powerValue(keep);
    frequency = frequency(keep);
    info.windowSamples = windowSamples;
    info.windowSecondsActual = windowSamples / sampleRate;
    info.overlapSamples = overlapSamples;
    info.overlapFraction = overlapSamples / windowSamples;
    info.nfft = nfft;
    info.detrend = options.welch.detrend;
    info.segmentCount = max(1, floor((numel(x) - overlapSamples) / ...
        max(1, windowSamples - overlapSamples)));
end


function [result, peaks] = fitAperiodic(frequency, powerValue, options)
    mask = inRange(frequency, options.frequencyRangeHz) & frequency > 0 & ...
        isfinite(powerValue) & powerValue > 0;
    for irange = 1:size(options.excludeRangesHz, 1)
        mask = mask & ~inRange(frequency, options.excludeRangesHz(irange, :));
    end
    f = frequency(mask);
    logPower = log10(powerValue(mask));
    peaks = emptyPeakTableWithoutChannel();
    result = struct('exponent', NaN, 'offset', NaN, 'fitR2', NaN, ...
        'frequencyHz', f, 'observedLog10Power', logPower, ...
        'fittedLog10Power', nan(size(f)), 'residual', nan(size(f)));
    if numel(f) < 5, return; end

    logFrequency = log10(f);
    initial = polyfit(logFrequency, logPower, 1);
    residual = logPower - polyval(initial, logFrequency);
    robustScale = 1.4826 * median(abs(residual - median(residual)));
    if ~isfinite(robustScale) || robustScale <= eps
        robustScale = std(residual);
    end
    peakMask = residual > options.peakThresholdSD * max(robustScale, eps);
    fitMask = ~peakMask;
    if sum(fitMask) < 5, fitMask(:) = true; end
    coefficients = polyfit(logFrequency(fitMask), logPower(fitMask), 1);
    fitted = polyval(coefficients, logFrequency);
    residual = logPower - fitted;
    result.exponent = -coefficients(1);
    result.offset = coefficients(2);
    result.fitR2 = coefficientOfDetermination(logPower(fitMask), ...
        fitted(fitMask));
    result.fittedLog10Power = fitted;
    result.residual = residual;

    candidates = localPeakCandidates(f, residual, options);
    if isempty(candidates), return; end
    peakIndex = (1:numel(candidates))';
    center = f(candidates);
    excess = residual(candidates);
    bandwidth = estimatePeakBandwidths(f, residual, candidates);
    peaks = table(peakIndex, center, excess, bandwidth, ...
        'VariableNames', {'peak_index', 'center_frequency_hz', ...
        'peak_excess_log10', 'bandwidth_hz'});
end


function indices = localPeakCandidates(frequency, residual, options)
    if options.maxPeaks == 0
        indices = zeros(0, 1); return;
    end
    if numel(residual) < 3
        indices = zeros(0, 1); return;
    end
    scale = 1.4826 * median(abs(residual - median(residual)));
    threshold = options.peakThresholdSD * max(scale, eps);
    local = find(residual(2:end-1) >= residual(1:end-2) & ...
        residual(2:end-1) > residual(3:end) & ...
        residual(2:end-1) > threshold) + 1;
    [~, order] = sort(residual(local), 'descend');
    selected = zeros(0, 1);
    for candidate = local(order(:))'
        if isempty(selected) || all(abs(frequency(candidate) - ...
                frequency(selected)) >= options.minPeakDistanceHz)
            selected(end + 1, 1) = candidate; %#ok<AGROW>
        end
        if numel(selected) >= options.maxPeaks, break; end
    end
    [~, order] = sort(frequency(selected));
    indices = selected(order);
end


function widths = estimatePeakBandwidths(frequency, residual, indices)
    widths = nan(numel(indices), 1);
    for ipeak = 1:numel(indices)
        index = indices(ipeak);
        halfHeight = residual(index) / 2;
        left = index;
        right = index;
        while left > 1 && residual(left) > halfHeight, left = left - 1; end
        while right < numel(residual) && residual(right) > halfHeight
            right = right + 1;
        end
        widths(ipeak) = frequency(right) - frequency(left);
    end
end


function tableValue = calculateFAA(details, channelNames, options)
    tableValue = table('Size', [0, 8], ...
        'VariableTypes', {'double', 'string', 'string', 'double', ...
        'double', 'double', 'string', 'string'}, ...
        'VariableNames', {'pair_index', 'left_channel', 'right_channel', ...
        'left_channel_index', 'right_channel_index', 'faa', ...
        'direction', 'status'});
    if ~ismember("faa", options.metrics), return; end
    alphaIndex = find(strcmpi(options.bands.names, 'alpha'), 1);
    for ipair = 1:size(options.faa.pairs, 1)
        leftName = options.faa.pairs(ipair, 1);
        rightName = options.faa.pairs(ipair, 2);
        leftIndex = find(strcmpi(channelNames, leftName), 1);
        rightIndex = find(strcmpi(channelNames, rightName), 1);
        value = NaN;
        pairStatus = "ok";
        if isempty(alphaIndex)
            pairStatus = "alpha_band_not_defined";
        elseif isempty(leftIndex) || isempty(rightIndex)
            pairStatus = "channel_not_found";
        else
            leftPower = detailBandPower(details, alphaIndex, leftIndex);
            rightPower = detailBandPower(details, alphaIndex, rightIndex);
            leftLog = faaTransform(leftPower, options.faa.transform);
            rightLog = faaTransform(rightPower, options.faa.transform);
            if options.faa.direction == "right_minus_left"
                value = rightLog - leftLog;
            else
                value = leftLog - rightLog;
            end
            if ~isfinite(value), pairStatus = "invalid_alpha_power"; end
        end
        tableValue(end + 1, :) = {ipair, leftName, rightName, ...
            valueOrNaN(leftIndex), valueOrNaN(rightIndex), value, ...
            options.faa.direction, pairStatus}; %#ok<AGROW>
    end
end


function value = detailBandPower(details, bandIndex, channelIndex)
    value = NaN;
    if channelIndex <= numel(details) && isstruct(details{channelIndex}) && ...
            isfield(details{channelIndex}, 'bandPower') && ...
            numel(details{channelIndex}.bandPower) >= bandIndex
        value = details{channelIndex}.bandPower(bandIndex);
    end
end


function names = scalarMetricNames(options)
    names = strings(0, 1);
    bandNames = validBandName(options.bands.names);
    if any(ismember(options.metrics, ["absolute_power", "relative_power", ...
            "log_power", "theta_beta_ratio", "alpha_theta_ratio", ...
            "high_low_ratio", "faa"]))
        names(end + 1) = "total_power";
    end
    if ismember("absolute_power", options.metrics)
        names = [names; "absolute_power_" + bandNames(:)];
    end
    if ismember("relative_power", options.metrics)
        names = [names; "relative_power_" + bandNames(:)];
    end
    if ismember("log_power", options.metrics)
        names = [names; logPowerName(options.logTransform, bandNames(:))];
    end
    if ismember("spectral_shape", options.metrics)
        names = [names; "peak_frequency_hz"; "peak_power"; ...
            "spectral_centroid_hz"; "median_frequency_hz"; "bandwidth_hz"];
    end
    if ismember("spectral_flatness", options.metrics)
        names(end + 1) = "spectral_flatness";
    end
    if ismember("spectral_edge", options.metrics)
        for fraction = options.shape.edgeFractions(:)'
            names(end + 1) = "spectral_edge_" + ...
                string(round(fraction * 100)) + "_hz"; %#ok<AGROW>
        end
    end
    if ismember("individual_alpha_peak", options.metrics)
        names = [names; "individual_alpha_peak_hz"; ...
            "individual_alpha_peak_power"];
    end
    if ismember("aperiodic", options.metrics)
        names = [names; "aperiodic_exponent"; "aperiodic_offset"; ...
            "aperiodic_fit_r2"];
    end
    if ismember("theta_beta_ratio", options.metrics)
        names(end + 1) = "theta_beta_ratio";
    end
    if ismember("alpha_theta_ratio", options.metrics)
        names(end + 1) = "alpha_theta_ratio";
    end
    if ismember("high_low_ratio", options.metrics)
        names(end + 1) = "alpha_beta_over_delta_theta";
    end
    names = unique(names, 'stable');
end


function [x, status] = prepareValues(original, options, missingFraction)
    valid = isfinite(original);
    status = "ok";
    if missingFraction > options.missing.maxFraction
        if options.missing.method == "reject_file"
            error("缺失比例%.3f超过阈值，按reject_file拒绝文件。", missingFraction);
        elseif options.missing.method == "reject_channel"
            x = []; status = "rejected_missing_fraction"; return;
        end
    end
    switch options.missing.method
        case {"omit", "reject_channel", "reject_file"}
            x = original(valid);
        case "zero"
            x = original; x(~valid) = 0;
        case {"linear", "nearest"}
            x = fillmissing(original, char(options.missing.method), ...
                'EndValues', 'nearest');
        case "previous"
            x = fillmissing(original, 'previous');
            x = fillmissing(x, 'next');
    end
    x = double(x(:));
    x = x(isfinite(x));
    if numel(x) < options.missing.minimumValidSamples
        x = []; status = "insufficient_valid_samples";
    elseif missingFraction > 0
        status = "missing_handled_" + options.missing.method;
    end
end


function value = integrateRange(frequency, powerValue, rangeHz)
    mask = inRange(frequency, rangeHz);
    if sum(mask) < 2, value = NaN; else, value = trapz(frequency(mask), powerValue(mask)); end
end

function mask = inRange(frequency, rangeHz)
    mask = frequency >= rangeHz(1) & frequency <= rangeHz(2);
end

function value = spectralQuantile(frequency, powerValue, fraction)
    value = NaN;
    if isempty(frequency) || sum(powerValue) <= 0, return; end
    cumulative = cumtrapz(frequency, powerValue);
    target = fraction * cumulative(end);
    index = find(cumulative >= target, 1);
    if ~isempty(index), value = frequency(index); end
end

function value = weightedMean(x, weights)
    value = safeDivide(sum(x .* weights), sum(weights));
end

function value = safeDivide(numerator, denominator)
    if ~isfinite(denominator) || abs(denominator) <= eps
        value = NaN;
    else
        value = numerator / denominator;
    end
end

function value = transformPower(powerValue, method)
    if ~isfinite(powerValue) || powerValue <= 0, value = NaN; return; end
    if method == "db", value = 10 * log10(powerValue); else, value = log10(powerValue); end
end

function value = faaTransform(powerValue, method)
    if ~isfinite(powerValue) || powerValue <= 0, value = NaN; return; end
    switch method
        case "natural_log", value = log(powerValue);
        case "log10", value = log10(powerValue);
        otherwise, value = 10 * log10(powerValue);
    end
end

function value = bandRatio(map, numerator, denominator)
    value = safeDivide(bandValue(map, numerator), bandValue(map, denominator));
end

function value = bandValue(map, name)
    key = char(validBandName(name));
    if isKey(map, key), value = map(key); else, value = NaN; end
end

function value = validBandName(value)
    value = string(matlab.lang.makeValidName(lower(string(value)), ...
        'ReplacementStyle', 'underscore'));
end

function value = logPowerName(transform, bandName)
    if transform == "db", prefix = "log_power_db_"; else, prefix = "log_power_log10_"; end
    value = prefix + string(bandName);
end

function value = coefficientOfDetermination(actual, fitted)
    denominator = sum((actual - mean(actual)).^2);
    if denominator <= eps, value = NaN; else, value = 1 - sum((actual - fitted).^2) / denominator; end
end

function value = valueOrNaN(index)
    if isempty(index), value = NaN; else, value = index; end
end

function tableValue = emptySpectrumTable()
    tableValue = table('Size', [0, 4], ...
        'VariableTypes', {'double', 'double', 'double', 'double'}, ...
        'VariableNames', {'channel_index', 'frequency_hz', 'power', 'power_db_hz'});
end

function tableValue = emptyPeakTable()
    tableValue = table('Size', [0, 5], ...
        'VariableTypes', {'double', 'double', 'double', 'double', 'double'}, ...
        'VariableNames', {'channel_index', 'peak_index', ...
        'center_frequency_hz', 'peak_excess_log10', 'bandwidth_hz'});
end

function tableValue = emptyPeakTableWithoutChannel()
    tableValue = table('Size', [0, 4], ...
        'VariableTypes', {'double', 'double', 'double', 'double'}, ...
        'VariableNames', {'peak_index', 'center_frequency_hz', ...
        'peak_excess_log10', 'bandwidth_hz'});
end

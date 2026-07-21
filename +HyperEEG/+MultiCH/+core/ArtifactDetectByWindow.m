function [badIntervals, detectionInfo] = ArtifactDetectByWindow(EEGdata, options)
%ARTIFACTDETECTBYWINDOW 使用滑动窗口、多指标投票自动识别坏段。
%   输出区间与EEGdata.times单位和时间基准一致。本函数只识别和记录，
%   不删除数据；默认阈值偏宽松，用于辅助人工复核而非替代人工判断。

    if nargin < 2 || isempty(options)
        options = struct();
    end

    options = setDefaultOptions(options, EEGdata);
    [data, timeValues] = validateInput(EEGdata);

    nChannel = size(data, 1);
    nSample = size(data, 2);
    windowSample = max(4, round( ...
        options.windowDuration_s * options.sampleRate));
    stepSample = max(1, round( ...
        windowSample * (1 - options.windowOverlap)));

    [blockStart, blockEnd, sampleBlock] = findContinuousBlock(timeValues);
    [windowStart, windowEnd] = buildWindows( ...
        blockStart, blockEnd, windowSample, stepSample);
    nWindow = numel(windowStart);

    badIntervals = zeros(0, 2);
    detectionInfo = initializeInfo(options, windowStart, windowEnd, ...
        timeValues, nChannel);

    if nSample < windowSample || nWindow < options.minWindowCount
        detectionInfo.status = "insufficient_windows";
        return;
    end

    %%==========================================================
    % 计算各窗口特征
    %%==========================================================

    peakToPeak = zeros(nChannel, nWindow);
    jumpAmplitude = zeros(nChannel, nWindow);
    highFrequencyRatio = zeros(nChannel, nWindow);
    robustScale = zeros(nChannel, nWindow);
    invalidChannel = false(nChannel, nWindow);
    logCovariance = zeros(nChannel * nChannel, nWindow);

    for iwindow = 1:nWindow
        currentData = data(:, windowStart(iwindow):windowEnd(iwindow));
        invalidChannel(:, iwindow) = any(~isfinite(currentData), 2);
        currentData = fillInvalidValue(currentData);
        currentData = currentData - median(currentData, 2);
        differenceData = diff(currentData, 1, 2);

        peakToPeak(:, iwindow) = max(currentData, [], 2) - ...
            min(currentData, [], 2);
        jumpAmplitude(:, iwindow) = max(abs(differenceData), [], 2);
        robustScale(:, iwindow) = 1.4826 * ...
            median(abs(currentData), 2);

        signalRms = sqrt(mean(currentData .^ 2, 2));
        differenceRms = sqrt(mean(differenceData .^ 2, 2));
        highFrequencyRatio(:, iwindow) = differenceRms ./ ...
            max(signalRms, eps);

        if nChannel > 1
            covarianceMatrix = currentData * currentData' / ...
                max(size(currentData, 2) - 1, 1);
            regularization = max(trace(covarianceMatrix) / nChannel, eps);
            covarianceMatrix = covarianceMatrix + eye(nChannel) * ...
                regularization * options.covarianceRegularization;
            logMatrix = real(logm(covarianceMatrix));
            logCovariance(:, iwindow) = logMatrix(:);
        end
    end

    %%==========================================================
    % 稳健异常分数与多指标投票
    %%==========================================================

    peakToPeakZ = robustZ(log(max(peakToPeak, eps)), 2);
    jumpZ = robustZ(log(max(jumpAmplitude, eps)), 2);
    highFrequencyZ = robustZ(log(max(highFrequencyRatio, eps)), 2);
    scaleZ = robustZ(log(max(robustScale, eps)), 2);

    channelReferenceScale = median(robustScale, 2);
    flatThreshold = max(channelReferenceScale * ...
        options.flatScaleRatio, eps);

    metricFlag = false(nChannel, nWindow, 4);
    metricFlag(:, :, 1) = peakToPeakZ > options.robustZThreshold;
    metricFlag(:, :, 2) = jumpZ > options.robustZThreshold;
    metricFlag(:, :, 3) = highFrequencyZ > options.robustZThreshold;
    metricFlag(:, :, 4) = scaleZ < -options.robustZThreshold | ...
        robustScale <= flatThreshold;

    metricVote = sum(metricFlag, 3);
    severeChannel = peakToPeakZ > options.severeZThreshold | ...
        jumpZ > options.severeZThreshold | ...
        highFrequencyZ > options.severeZThreshold | ...
        scaleZ < -options.severeZThreshold;
    channelBad = metricVote >= options.minMetricVotes | ...
        severeChannel | invalidChannel;

    covarianceZ = zeros(1, nWindow);
    covarianceFlag = false(1, nWindow);

    if nChannel > 1
        covarianceCenter = median(logCovariance, 2);
        covarianceDistance = sqrt(sum( ...
            (logCovariance - covarianceCenter) .^ 2, 1));
        covarianceZ = robustZ(covarianceDistance, 2);
        covarianceFlag = covarianceZ > options.covarianceZThreshold;
    end

    minBadChannel = max(1, ceil( ...
        nChannel * options.minBadChannelRatio));
    metricSupport = squeeze(any(metricFlag, 1));
    metricSupport = any(metricSupport, 2)';

    windowBad = sum(channelBad, 1) >= minBadChannel | ...
        (covarianceFlag & metricSupport) | ...
        covarianceZ > options.severeZThreshold;

    %%==========================================================
    % 将坏窗口合并为时间区间
    %%==========================================================

    mergeGapSample = round(options.mergeGap_s * options.sampleRate);
    badWindowIndex = find(windowBad);

    if ~isempty(badWindowIndex)
        badStart = windowStart(badWindowIndex);
        badEnd = windowEnd(badWindowIndex);
        [badStart, badEnd] = mergeSampleInterval( ...
            badStart, badEnd, sampleBlock, mergeGapSample);
        badIntervals = [timeValues(badStart)', timeValues(badEnd)'];
    end

    detectionInfo.status = "completed";
    detectionInfo.metric_z.peak_to_peak = peakToPeakZ;
    detectionInfo.metric_z.jump = jumpZ;
    detectionInfo.metric_z.high_frequency = highFrequencyZ;
    detectionInfo.metric_z.scale = scaleZ;
    detectionInfo.metric_flag = metricFlag;
    detectionInfo.channel_bad = channelBad;
    detectionInfo.covariance_z = covarianceZ;
    detectionInfo.window_bad = windowBad;
    detectionInfo.bad_intervals = badIntervals;

end

function options = setDefaultOptions(options, EEGdata)
%SETDEFAULTOPTIONS 补齐检测参数，并从EEGdata解析或估算采样率。

    defaultOptions.windowDuration_s = 2;
    defaultOptions.windowOverlap = 0.5;
    defaultOptions.robustZThreshold = 6;
    defaultOptions.severeZThreshold = 10;
    defaultOptions.minMetricVotes = 2;
    defaultOptions.minBadChannelRatio = 0.25;
    defaultOptions.covarianceZThreshold = 6;
    defaultOptions.covarianceRegularization = 1e-6;
    defaultOptions.flatScaleRatio = 1e-4;
    defaultOptions.mergeGap_s = 0.25;
    defaultOptions.minWindowCount = 8;

    optionNames = fieldnames(defaultOptions);

    for ioption = 1:numel(optionNames)
        currentName = optionNames{ioption};

        if ~isfield(options, currentName) || isempty(options.(currentName))
            options.(currentName) = defaultOptions.(currentName);
        end
    end

    if ~isfield(options, 'sampleRate') || isempty(options.sampleRate)
        if isfield(EEGdata, 'etc') && ...
                isfield(EEGdata.etc, 'samplerate') && ...
                isfield(EEGdata.etc.samplerate, 'raw')
            options.sampleRate = EEGdata.etc.samplerate.raw;
        else
            error("缺少采样率，请设置options.sampleRate。");
        end
    end

    validateattributes(options.sampleRate, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
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

function [data, timeValues] = validateInput(EEGdata)
%VALIDATEINPUT 验证通道×采样点数据矩阵及对应时间轴。

    if ~isstruct(EEGdata) || ~isscalar(EEGdata) || ...
            ~isfield(EEGdata, 'data') || ~isfield(EEGdata, 'times')
        error("EEGdata必须为包含data和times字段的标量结构体。");
    end

    data = double(EEGdata.data);
    timeValues = double(EEGdata.times(:)');

    if isempty(data) || isempty(timeValues)
        error("EEGdata.data和EEGdata.times不能为空。");
    end

    if ~isreal(data) || size(data, 2) ~= numel(timeValues)
        error("EEGdata.data必须为通道×采样点实数矩阵，并与times对应。");
    end

    if any(~isfinite(timeValues))
        error("EEGdata.times包含无效时间值。");
    end

end

function [blockStart, blockEnd, sampleBlock] = findContinuousBlock(timeValues)
%FINDCONTINUOUSBLOCK 定位时间轴断点并分配连续片段编号。

    timeDifference = diff(timeValues);
    positiveDifference = timeDifference(timeDifference > 0);

    if isempty(positiveDifference)
        breakIndex = 1:(numel(timeValues) - 1);
    else
        referenceStep = median(positiveDifference);
        breakIndex = find(timeDifference <= 0 | ...
            timeDifference > referenceStep * 3);
    end

    blockStart = [1, breakIndex + 1];
    blockEnd = [breakIndex, numel(timeValues)];
    sampleBlock = zeros(1, numel(timeValues));

    for iblock = 1:numel(blockStart)
        sampleBlock(blockStart(iblock):blockEnd(iblock)) = iblock;
    end

end

function [windowStart, windowEnd] = buildWindows( ...
        blockStart, blockEnd, windowSample, stepSample)
%BUILDWINDOWS 在每个连续片段内部生成滑动窗口，不跨片段取样。

    windowStart = [];
    windowEnd = [];

    for iblock = 1:numel(blockStart)
        lastStart = blockEnd(iblock) - windowSample + 1;

        if lastStart < blockStart(iblock)
            continue;
        end

        currentStart = blockStart(iblock):stepSample:lastStart;

        if currentStart(end) ~= lastStart
            currentStart(end + 1) = lastStart; %#ok<AGROW>
        end

        windowStart = [windowStart, currentStart]; %#ok<AGROW>
        windowEnd = [windowEnd, currentStart + windowSample - 1]; %#ok<AGROW>
    end

end

function data = fillInvalidValue(data)
%FILLINVALIDVALUE 为特征计算临时填补NaN/Inf，不修改原始EEGdata。

    for ichannel = 1:size(data, 1)
        validValue = data(ichannel, isfinite(data(ichannel, :)));

        if isempty(validValue)
            data(ichannel, :) = 0;
        else
            data(ichannel, ~isfinite(data(ichannel, :))) = ...
                median(validValue);
        end
    end

end

function zScore = robustZ(values, dimension)
%ROBUSTZ 沿指定维度使用中位数与MAD计算稳健异常分数。

    centerValue = median(values, dimension);
    absoluteDeviation = median(abs(values - centerValue), dimension);
    scaleFloor = max(abs(centerValue), 1) * 1e-12;
    robustScale = max(absoluteDeviation, scaleFloor);
    zScore = 0.67448975 * (values - centerValue) ./ robustScale;

end

function [mergedStart, mergedEnd] = mergeSampleInterval( ...
        intervalStart, intervalEnd, sampleBlock, mergeGapSample)
%MERGESAMPLEINTERVAL 合并同一连续片段中重叠或相近的样本区间。

    mergedStart = intervalStart(1);
    mergedEnd = intervalEnd(1);

    for iinterval = 2:numel(intervalStart)
        sameBlock = sampleBlock(intervalStart(iinterval)) == ...
            sampleBlock(mergedEnd(end));
        closeEnough = intervalStart(iinterval) <= ...
            mergedEnd(end) + mergeGapSample + 1;

        if sameBlock && closeEnough
            mergedEnd(end) = max(mergedEnd(end), intervalEnd(iinterval));
        else
            mergedStart(end + 1) = intervalStart(iinterval); %#ok<AGROW>
            mergedEnd(end + 1) = intervalEnd(iinterval); %#ok<AGROW>
        end
    end

end

function detectionInfo = initializeInfo(options, windowStart, windowEnd, ...
        timeValues, nChannel)
%INITIALIZEINFO 建立固定字段的检测详情，便于日志和参数比较。

    detectionInfo.status = "not_started";
    detectionInfo.parameters = options;
    detectionInfo.window_sample = [windowStart', windowEnd'];

    if isempty(windowStart)
        detectionInfo.window_time = zeros(0, 2);
    else
        detectionInfo.window_time = [ ...
            timeValues(windowStart)', timeValues(windowEnd)'];
    end

    detectionInfo.metric_z = struct();
    detectionInfo.metric_flag = false(nChannel, numel(windowStart), 4);
    detectionInfo.channel_bad = false(nChannel, numel(windowStart));
    detectionInfo.covariance_z = zeros(1, numel(windowStart));
    detectionInfo.window_bad = false(1, numel(windowStart));
    detectionInfo.bad_intervals = zeros(0, 2);

end

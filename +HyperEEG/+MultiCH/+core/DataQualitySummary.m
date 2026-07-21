function [EEGdata, qualityInfo] = DataQualitySummary(EEGdata)
%DATAQUALITYSUMMARY 计算清洗后各通道和整份数据的有效比例。
%   有效样本定义为有限数值；整条均为NaN/Inf的通道记为坏导。
%   总时长由完整时间轴跨度估算，因此全局坏段删除形成的时间缺口仍计入
%   分母。结果只写入EEGdata.quality，不在EEGdata顶层复制质量字段。

    validateEEGdata(EEGdata);
    sampleRate = HyperEEG.MultiCH.core.PreprocessSampleRate(EEGdata);
    nChannel = size(EEGdata.data, 1);
    totalSampleEquivalent = estimateTotalSampleEquivalent( ...
        EEGdata.times, sampleRate, size(EEGdata.data, 2));
    finiteMask = isfinite(EEGdata.data);
    validSampleCount = sum(finiteMask, 2);
    channelRate = min(max( ...
        double(validSampleCount) ./ totalSampleEquivalent, 0), 1);
    badChannels = find(validSampleCount == 0)';
    overallRate = sum(validSampleCount) / ...
        (totalSampleEquivalent * nChannel);
    overallRate = min(max(double(overallRate), 0), 1);
    channelRateCell = buildChannelRateCell(channelRate);

    qualityInfo = struct();
    qualityInfo.isValid = 1;
    qualityInfo.deletionReason = "";
    qualityInfo.badchannel = badChannels;
    qualityInfo.channelrate = channelRateCell;
    qualityInfo.totalEffectiveRate = overallRate;
    qualityInfo.sampleRate_Hz = sampleRate;
    qualityInfo.totalSampleEquivalent = totalSampleEquivalent;
    qualityInfo.totalDuration_s = totalSampleEquivalent / sampleRate;
    qualityInfo.validDuration_s = double(validSampleCount(:)') / sampleRate;

    obsoleteFields = intersect(fieldnames(EEGdata), ...
        {'badchannel', 'channelrate', 'channelrateText', 'rate'});

    if ~isempty(obsoleteFields)
        EEGdata = rmfield(EEGdata, obsoleteFields);
    end

    EEGdata.quality = qualityInfo;
    EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
        EEGdata, "quality_summary", 1);

end

function totalSampleEquivalent = estimateTotalSampleEquivalent( ...
        timeValues, sampleRate, fallbackSampleCount)
%ESTIMATETOTALSAMPLEEQUIVALENT 将时间跨度换算成当前采样率下的总点数。

    finiteTimes = double(timeValues(isfinite(timeValues)));

    if numel(finiteTimes) < 2
        totalSampleEquivalent = fallbackSampleCount;
        return;
    end

    timeDifference = diff(finiteTimes(:));
    normalDifference = timeDifference( ...
        isfinite(timeDifference) & timeDifference > 0);

    if isempty(normalDifference)
        totalSampleEquivalent = fallbackSampleCount;
        return;
    end

    nominalStep = median(normalDifference);
    totalSampleEquivalent = round( ...
        (max(finiteTimes) - min(finiteTimes)) / nominalStep) + 1;
    totalSampleEquivalent = max( ...
        double(totalSampleEquivalent), double(fallbackSampleCount));

    if ~isfinite(totalSampleEquivalent) || totalSampleEquivalent <= 0
        totalSampleEquivalent = fallbackSampleCount;
    end

    % 采样率参数在此处作为数据契约校验，避免无效采样率静默进入结果。
    if ~isfinite(sampleRate) || sampleRate <= 0
        error("采样率必须为正数。");
    end

end

function outputCell = buildChannelRateCell(channelRate)
%BUILDCHANNELRATECELL 生成左列通道名、右列数值比例的N×2 cell。

    nChannel = numel(channelRate);
    outputCell = cell(nChannel, 2);

    for ichannel = 1:nChannel
        outputCell{ichannel, 1} = char("ch" + string(ichannel));
        outputCell{ichannel, 2} = double(channelRate(ichannel));
    end

end

function validateEEGdata(EEGdata)
%VALIDATEEEGDATA 检查质量汇总所需的最小字段。

    if ~isstruct(EEGdata) || ~isscalar(EEGdata) || ...
            ~isfield(EEGdata, "data") || ...
            ~isfield(EEGdata, "times")
        error("EEGdata必须为包含data和times字段的标量结构体。");
    end

    if ~isnumeric(EEGdata.data) || ~ismatrix(EEGdata.data) || ...
            isempty(EEGdata.data)
        error("EEGdata.data必须为非空的通道×采样点数值矩阵。");
    end

    if ~isnumeric(EEGdata.times) || ...
            numel(EEGdata.times) ~= size(EEGdata.data, 2)
        error("EEGdata.times长度必须与数据采样点数一致。");
    end

end

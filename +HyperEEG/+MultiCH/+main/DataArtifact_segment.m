function [EEGdata, removedSampleCount, maskedValueCount] = ...
        DataArtifact_segment(EEGdata, outsegment)
%DATAARTIFACT_SEGMENT 根据人工/自动标记统一处理坏时间段和坏导。
%   channel=0删除公共时间列；channel>0只将对应通道区间设为NaN，
%   从而保持多人及多通道数据共享同一时间轴。

    removedSampleCount = 0;
    maskedValueCount = 0;

    %%==========================================================
    % 基础检查
    %%==========================================================

    if ~isstruct(EEGdata) || ~isscalar(EEGdata)
        error("EEGdata必须为标量结构体。");
    end

    if ~isfield(EEGdata, "times") || ~isfield(EEGdata, "data")
        error("EEGdata必须包含times和data字段。");
    end

    if size(EEGdata.data, 2) ~= numel(EEGdata.times)
        error("EEGdata.data的采样点数必须与EEGdata.times长度一致。");
    end

    if isempty(outsegment)
        return;
    end

    nChannel = size(EEGdata.data, 1);
    segmentList = normalizeSegment(outsegment, nChannel);

    %%==========================================================
    % channel=0：删除所有通道共同的坏时间段
    %%==========================================================

    globalSegment = segmentList([segmentList.channel] == 0);
    keepSample = true(size(EEGdata.times));

    for isegment = 1:numel(globalSegment)
        currentInterval = globalSegment(isegment).intervals;

        for iinterval = 1:size(currentInterval, 1)
            badSample = EEGdata.times >= currentInterval(iinterval, 1) & ...
                EEGdata.times <= currentInterval(iinterval, 2);
            keepSample = keepSample & ~badSample;
        end
    end

    removedSampleCount = sum(~keepSample);
    EEGdata.times = EEGdata.times(keepSample);
    EEGdata.data = EEGdata.data(:, keepSample);

    %%==========================================================
    % channel>0：只屏蔽指定通道，保持矩阵和时间轴一致
    %%==========================================================

    channelSegment = segmentList([segmentList.channel] > 0);

    if ~isempty(channelSegment) && ~isfloat(EEGdata.data)
        EEGdata.data = double(EEGdata.data);
    end

    for isegment = 1:numel(channelSegment)
        channelIndex = channelSegment(isegment).channel;
        currentInterval = channelSegment(isegment).intervals;

        for iinterval = 1:size(currentInterval, 1)
            badSample = EEGdata.times >= currentInterval(iinterval, 1) & ...
                EEGdata.times <= currentInterval(iinterval, 2);
            validValue = ~isnan(EEGdata.data(channelIndex, badSample));
            maskedValueCount = maskedValueCount + sum(validValue);
            EEGdata.data(channelIndex, badSample) = NaN;
        end
    end

end

function segmentList = normalizeSegment(outsegment, nChannel)
%NORMALIZESEGMENT 将旧数值区间和不同结构格式统一为channel/intervals。

    segmentList = struct('channel', {}, 'intervals', {});

    if isnumeric(outsegment)
        segmentList(1).channel = 0;
        segmentList(1).intervals = validateInterval(outsegment);
        return;
    end

    if ~isstruct(outsegment)
        error("outsegment必须为数值区间或坏段结构体。");
    end

    if isfield(outsegment, 'intervals')
        for isegment = 1:numel(outsegment)
            segmentList(isegment).channel = parseChannel( ...
                outsegment(isegment), nChannel);
            segmentList(isegment).intervals = validateInterval( ...
                outsegment(isegment).intervals);
        end
        return;
    end

    if isfield(outsegment, 'start') && isfield(outsegment, 'end')
        for isegment = 1:numel(outsegment)
            segmentList(isegment).channel = parseChannel( ...
                outsegment(isegment), nChannel);
            startValue = parseBoundary( ...
                outsegment(isegment).start, false, isegment);
            endValue = parseBoundary( ...
                outsegment(isegment).end, true, isegment);
            segmentList(isegment).intervals = validateInterval( ...
                [startValue, endValue]);
        end
        return;
    end

    error("坏段结构体必须包含intervals或start/end字段。");

end

function channelIndex = parseChannel(segmentInfo, nChannel)
%PARSECHANNEL 解析并验证通道编号；0表示所有通道。

    if isfield(segmentInfo, 'channel')
        channelValue = segmentInfo.channel;
    elseif isfield(segmentInfo, 'name')
        channelValue = segmentInfo.name;
    else
        channelValue = 0;
    end

    if ischar(channelValue) || ...
            (isstring(channelValue) && isscalar(channelValue))
        channelText = strtrim(string(channelValue));

        if any(strcmpi(channelText, ["auto", "all"]))
            channelIndex = 0;
            return;
        end

        channelIndex = str2double(channelText);
    elseif isnumeric(channelValue) && isscalar(channelValue)
        channelIndex = double(channelValue);
    else
        error("Channel格式错误。");
    end

    if isnan(channelIndex) || channelIndex < 0 || ...
            channelIndex > nChannel || channelIndex ~= fix(channelIndex)
        error("Channel必须是0到%d之间的整数，0表示所有通道。", nChannel);
    end

end

function intervals = validateInterval(intervals)
%VALIDATEINTERVAL 验证N×2时间区间及开始、结束顺序。

    if isempty(intervals)
        intervals = zeros(0, 2);
        return;
    end

    if ~isnumeric(intervals) || ~isreal(intervals) || ...
            size(intervals, 2) ~= 2
        error("坏段区间必须为N×2数值矩阵。");
    end

    intervals = double(intervals);

    if any(~isfinite(intervals(:, 1))) || ...
            any(isnan(intervals(:, 2)))
        error("坏段区间包含无效边界。");
    end

    if any(intervals(:, 2) <= intervals(:, 1))
        error("每个坏段的结束时间必须大于开始时间。");
    end

end

function boundary = parseBoundary(value, allowEnd, isegment)
%PARSEBOUNDARY 将数值文本和特殊值end转换为区间边界。

    if ischar(value) || (isstring(value) && isscalar(value))
        value = strtrim(string(value));

        if allowEnd && strcmpi(value, "end")
            boundary = inf;
            return;
        end

        boundary = str2double(value);
    elseif isnumeric(value) && isscalar(value)
        boundary = double(value);
    else
        error("第%d个坏段的边界格式错误。", isegment);
    end

    if isnan(boundary)
        error("第%d个坏段的边界不是有效数字。", isegment);
    end

end

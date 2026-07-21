function excludeFileBool = ...
        ArtifactIsWholeFileExcluded(segmentInfo, timeValues)
%ARTIFACTISWHOLEFILEEXCLUDED 判断channel=0标记是否覆盖整份数据。
%   只判断排除条件，不修改或删除任何文件。Pipeline根据返回值决定
%   是否跳过保存，从而保持原始_segment.mat只读。

    excludeFileBool = false;

    if isempty(segmentInfo) || isempty(timeValues)
        return;
    end

    finiteTimes = double(timeValues(isfinite(timeValues)));

    if isempty(finiteTimes)
        error("timeValues不包含有效时间值。");
    end

    firstTime = min(finiteTimes);
    lastTime = max(finiteTimes);

    for isegment = 1:numel(segmentInfo)
        if ~isfield(segmentInfo, "channel") || ...
                ~isfield(segmentInfo, "intervals") || ...
                segmentInfo(isegment).channel ~= 0
            continue;
        end

        intervals = segmentInfo(isegment).intervals;

        if ~isempty(intervals) && any( ...
                intervals(:, 1) <= firstTime & ...
                intervals(:, 2) >= lastTime)
            excludeFileBool = true;
            return;
        end
    end

end

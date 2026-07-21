function blocks = PreprocessContinuousBlocks(timeValues)
%PREPROCESSCONTINUOUSBLOCKS 按时间轴识别互不连续的采样片段。
%   blocks为N×2样本索引。相邻时间差非正、无效或超过典型步长3倍时
%   视为断点，避免滤波、去趋势和重采样跨越已删除的坏段。

    timeValues = double(timeValues(:)');

    if isempty(timeValues)
        blocks = zeros(0, 2);
        return;
    end

    % 使用正时间差中位数估计正常采样间隔，对少量异常间隔较稳健。
    timeDifference = diff(timeValues);
    positiveDifference = timeDifference( ...
        isfinite(timeDifference) & timeDifference > 0);

    if isempty(positiveDifference)
        breakIndex = 1:(numel(timeValues) - 1);
    else
        referenceStep = median(positiveDifference);
        breakIndex = find(~isfinite(timeDifference) | ...
            timeDifference <= 0 | timeDifference > referenceStep * 3);
    end

    blocks = [[1, breakIndex + 1]', ...
        [breakIndex, numel(timeValues)]'];

end

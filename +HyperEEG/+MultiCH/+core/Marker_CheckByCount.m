function abnormalidx = Marker_CheckByCount(markercount)
%MARKER_CHECKBYCOUNT 使用稳健统计查找Marker数量明显异常的文件。
%   输入为每个文件的Marker数，输出为原序列中的异常索引。

    markercount = markercount(:);
    
    validIdx = find(markercount ~= 0 & ~isnan(markercount));
    
    if isempty(validIdx)
        abnormalidx = [];
        return;
    end
    
    data = markercount(validIdx);
    
    % 中位数和MAD不容易被少量损坏文件拉偏。
    medv = median(data);
    madv = median(abs(data - medv));
    
    % 如果数据完全一致或MAD为0
    if madv == 0 || isnan(madv)
        abnormalidx = [];
        return;
    end
    
    % robust z-score (scaled MAD)
    robustZ = 0.6745 * (data - medv) / madv;
    
    outlierLocal = abs(robustZ) > 3.5;
    
    abnormalidx = validIdx(outlierLocal);

end

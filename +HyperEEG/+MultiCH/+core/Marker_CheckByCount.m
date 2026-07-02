function abnormalidx = Marker_CheckByCount(markercount)

    markercount = markercount(:);
    
    validIdx = find(markercount ~= 0 & ~isnan(markercount));
    
    if isempty(validIdx)
        abnormalidx = [];
        return;
    end
    
    data = markercount(validIdx);
    
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
function segmentInterval = Segmentmerge(segmentindex)
%SEGMENTMERGE 按名称分组并合并重叠或相接的时间区间。
%   End="end"统一转换为Inf，输出为name/intervals标准结构。

    names = {segmentindex.name};
    uniqueNames = unique(names);
    
    segmentInterval = struct([]);
    
    for i = 1:length(uniqueNames)
    
        thisName = uniqueNames{i};
    
        idx = strcmp(names, thisName);
    
        starts = [segmentindex(idx).start];
        ends   = {segmentindex(idx).end};
    
        % ==============================
        % 1. end 标准化
        % ==============================
        endNum = zeros(size(starts));
    
        for i = 1:length(ends)
            if ischar(ends{i}) || isstring(ends{i})
                if strcmpi(strtrim(ends{i}), 'end')
                    endNum(i) = inf;
                else
                    endNum(i) = str2double(ends{i});
                end
            else
                endNum(i) = ends{i};
            end
        end
    
        % ==============================
        % 2. 排序
        % ==============================
        [starts, order] = sort(starts);
        endNum = endNum(order);
    
        % ==============================
        % 3. 合并区间
        % ==============================
        intervals = [];
    
        curStart = starts(1);
        curEnd   = endNum(1);
    
        for i = 2:length(starts)
    
            s = starts(i);
            e = endNum(i);
    
            % ==========================
            % 判断是否“连续/重叠”
            % ==========================
            if s <= curEnd   % 重叠或连续 → 合并
                curEnd = max(curEnd, e);
            else
                % 断开 → 存旧区间
                intervals(end+1, :) = [curStart curEnd];
    
                % 开新段
                curStart = s;
                curEnd   = e;
            end
        end
    
        % 收尾
        intervals(end+1, :) = [curStart curEnd];
    
        % ==============================
        % 4. 写入输出
        % ==============================
        segmentInterval(end+1).name = thisName;
        segmentInterval(end).intervals = intervals;
    
    end


end

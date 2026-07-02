function dataflag = MarkerCheck_Auto(markerList,errorFiles,DataIgnorePath)
    
    nfiles = length(markerList);
    
    if nargin < 3 || isempty(DataIgnorePath)
        DataIgnorePath = '';
    end
    
    %设置返回数据
    info.filename = cell(nfiles,1);
    for i = 1:nfiles
        info.filename{i} = markerList{i}.filename;
    end
    
    dataflag = ones(nfiles,1);
    

    %检查是否为空
    if exist('errorFiles','var') && ~isempty(errorFiles)

        for i = 1:length(errorFiles)
            idx = find(strcmp(info.filename, errorFiles{i}));
            if ~isempty(idx)
                dataflag(idx) = 0;
            end
        end
    end
    
    if exist(DataIgnorePath, 'file') == 2 && ~isempty(DataIgnorePath)

        [~,~,dataIgnoreName] = xlsread(DataIgnorePath);
    
        if ~isempty(dataIgnoreName) && size(dataIgnoreName,1) > 1
    
            IgnoreList = string(dataIgnoreName(2:end));
            IgnoreList = IgnoreList(~ismissing(IgnoreList));
    
            allNames = string(info.filename);
    
            for i = 1:length(allNames)
                [~, name, ~] = fileparts(allNames(i));
                allNames(i) = name;
            end
    
            if ~isempty(IgnoreList)
    
                Ignoreidx = find(ismember(allNames, IgnoreList));
    
                if length(Ignoreidx) ~= length(IgnoreList)
                    fprintf("存在未被识别的忽略项，请注意检查！\n");
                end
    
                if ~isempty(Ignoreidx)
                    dataflag(Ignoreidx) = 0;
                end
    
            end
        end
    end

    %检查异常值
    lenList = nan(nfiles,1);
    
    for i = 1:nfiles
        if dataflag(i) == 1 && ~isempty(markerList{i}.marker)
            lenList(i) = length(markerList{i}.marker);
        end
    end
    
    abnormalidx = HyperEEG.MultiCH.core.Marker_CheckByCount(lenList);

    if ~isempty(abnormalidx)
        dataflag(abnormalidx) = 0;
    end
    
end
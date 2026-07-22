function [markerList,errorFiles] = MarkerList(inputDir)
%MARKERLIST 递归读取目录内全部BDF的Marker并汇总失败文件。
%   markerList保留文件路径和事件，errorFiles供自动质量标记使用。
    files = HyperEEG.MultiCH.misc.getFiles(inputDir,'BDF');
    nfiles = length(files);

    markerList = cell(nfiles,1);
    %% 逐个读取
    for i = 1 : nfiles
        HyperEEG.MultiCH.misc.WorkflowCancel("throw");
        
        filename = files(i);   % 直接就是完整路径
    
        fprintf('[%s]', datestr(now,'yyyy-mm-dd HH:MM:SS'));
        fprintf('正在读取: %s\n', filename);
    
        try
            [markerList{i}.marker, markerMetadata, readSuccess] = ...
                HyperEEG.MultiCH.main.MarkerExtract(filename);
            markerList{i}.sampleRate = markerMetadata.sampleRate;
            markerList{i}.firstTime_ms = markerMetadata.firstTime_ms;

            if ~readSuccess
                errorFiles{end+1,1} = filename; %#ok<AGROW>
            end

        catch ME
            warning('读取失败: %s | 原因: %s', filename, ME.message);
    
            markerList{i}.marker = [];                 % 失败占位
            markerList{i}.sampleRate = NaN;
            markerList{i}.firstTime_ms = 0;
            errorFiles{end+1,1} = filename;     % 记录错误文件
        end
            markerList{i}.filename = filename;
    end

    if exist('errorFiles','var')  % 先判断变量是否存在

        if ~isempty(errorFiles)   % 再判断是否为空
    
            fprintf(2, '\n\033[1;31m存在读取失败文件，共 %d 个：\033[0m\n', length(errorFiles));
    
            for i = 1:length(errorFiles)
                fprintf(2, '\033[1;31m%s\033[0m\n', errorFiles{i});
            end
    
        else
            fprintf('未发现读取失败文件。\n');
        end
    
    else
        errorFiles = {};   % 初始化（防止后续代码报错）
    end
end

function segment_Marker(segmentinfo,outputDir)
%SEGMENT_MARKER 根据人工确认区间切割BDF并保存_segment.mat。
%   只处理dataflag=1的文件；每个片段保留源路径、Marker和采集元数据。
    
    fileidx = find(segmentinfo.dataflag == 1);
    nfile = numel(fileidx);

    for ifile = 1:nfile
        
        clc
        EEGdata = struct();

        cdata = segmentinfo.segmentInterval(fileidx(ifile));
        filepath = cdata.filename;

        [~, name, ext] = fileparts(filepath);
        filename = name+ext;

        fprintf('[%s]', datestr(now,'yyyy-mm-dd HH:MM:SS'));
        fprintf("正在处理第 %d 个数据 %s 的切割,共 %d 个\n",ifile,filename,nfile);
        currentratio = ifile/nfile*100;
        fprintf('当前进度为 %.2f%%\n', currentratio);

        if ~isfile(filepath)
            warning("文件不存在：%s，已跳过。", filepath);
            continue;
        end

        % 每个BDF独立读取，单文件损坏不会中止其它文件。
        try
            evalc('cEEG = HyperEEG.MultiCH.core.BDFreader(filepath);');
        catch ME
            warning("读取失败：%s\n%s", filepath, ME.message);
            continue;
        end
        
        if isempty(cEEG) || isempty(cEEG.data)
            warning("EEG为空：%s", filepath);
            continue;
        end

        
        nsegment = length(cdata.intervals);
        
        for isegment = 1 :nsegment
            
            segmentname = cdata.intervals(isegment).name;
            cintervals = cdata.intervals(isegment);

            if isempty(cintervals.intervals)
                warning("%s 没有可切割区间，跳过。", segmentname);
                continue;
            end

            if size(cintervals.intervals,2) ~= 2
                warning("%s 的interval格式错误。", segmentname);
                continue;
            end

            EEGdata.file.filename = filename;
            EEGdata.file.rawpath = filepath;

            outputPath = outputDir + name +'_'+ segmentname + '_segment'+ '.mat';
            EEGdata.file.segmentname = segmentname;
            EEGdata.file.segmentpath = outputPath;

            EEGdata = HyperEEG.MultiCH.core.EEGdataSaver(EEGdata,cEEG);

            nsperate = size (cdata.intervals.intervals);
            
            seperatedata = struct();

            for iseperate = 1 :nsperate
                
                seperate_start = cintervals.intervals(iseperate , 1);
                seperate_end =  cintervals.intervals(iseperate , 2);

                seperate_idx = cEEG.times >= seperate_start & cEEG.times <= seperate_end;
                
                seperatedata(iseperate).times = cEEG.times(seperate_idx);
                seperatedata(iseperate).data  = cEEG.data(:, seperate_idx);
            end
            
            EEGdata.marker = cintervals.intervals;
            EEGdata.times = [seperatedata.times];
            EEGdata.data  = cat(2, seperatedata.data);
            EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                EEGdata, ["bdf_import", "marker_extract", ...
                "marker_auto", "marker_manual", "segment"], 1);

            if ~exist(outputDir,"dir")
                mkdir(outputDir);
            end
            
            save(outputPath, 'EEGdata');
            fprintf('[%s]', datestr(now,'yyyy-mm-dd HH:MM:SS'));
            fprintf("成功完成 %s 的切割\n" , filename);
            fprintf("已保存至 %s \n",outputPath);

        end

    end
end

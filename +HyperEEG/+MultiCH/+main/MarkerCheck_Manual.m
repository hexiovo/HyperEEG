function segmentinfo = MarkerCheck_Manual(dataflag,markerList,savekey)
%MARKERCHECK_MANUAL 逐文件打开Marker编辑器并保存标准分段信息。
%   用户取消某文件时将其dataflag设为0；savekey控制segmentinfo保存。

    nfiles = length(markerList);
    segmentInterval = struct([]);

    if nargin < 3 || isempty(savekey)
        savekey.bool = 0;
    end

    for i = 1:nfiles
        HyperEEG.MultiCH.misc.WorkflowCancel("throw");
        if dataflag(i) ~=0
            
            %赋值
            currentmarker.type = {markerList{i}.marker.type};
            currentmarker.sample_index = {markerList{i}.marker.latency};

            if ~isempty(markerList{i}.marker) && ...
                    isfield(markerList{i}.marker, 'time_ms')
                currentmarker.time_ms = {markerList{i}.marker.time_ms};
            else
                currentmarker.time_ms = currentmarker.sample_index;
                warning("Marker缺少time_ms，界面暂用原位置值：%s", ...
                    markerList{i}.filename);
            end

            currentfile = markerList{i}.filename;
            [~, name, ext] = fileparts(currentfile);
            currentfilename = name+ext;

            fprintf('[%s]', datestr(now,'yyyy-mm-dd HH:MM:SS'));
            fprintf('正在手动处理: %s\n', currentfilename);

            %返回对应列
            [segmentindex,emptybool] = HyperEEG.MultiCH.main.MarkerSegmentEditor(currentmarker,currentfilename);
            HyperEEG.MultiCH.misc.WorkflowCancel("throw");

            if emptybool == 1

                dataflag(i) = 0;
                segmentInterval(i).intervals = [];
                segmentInterval(i).filename = currentfile;
            
            else
                
                segmentInterval(i).intervals = HyperEEG.MultiCH.misc.Segmentmerge(segmentindex);
                segmentInterval(i).filename = currentfile;

            end
        else
            segmentInterval(i).intervals = [];
            segmentInterval(i).filename = markerList{i}.filename;
        end
    end

    if savekey.bool ==1
        savepath = savekey.path;
        segmentinfo.segmentInterval = segmentInterval;
        segmentinfo.dataflag = dataflag;

        % =========================
        % 自动保证 .mat 后缀
        % =========================
        [folder, name, ext] = fileparts(savepath);
        if isempty(ext)
            savepath = fullfile(folder, [name '.mat']);
        end
    
        % =========================
        % 保存
        % =========================
        save(savepath, 'segmentinfo');

        % =========================
        % 输出提示
        % =========================
        fprintf('Segment info saved to: %s\n', savepath);
    end
end

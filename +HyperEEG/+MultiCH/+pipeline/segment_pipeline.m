function segment_pipeline( ...
        RawInputDir, outputDir, DataIgnorePath, logSwitch)
%SEGMENT_PIPELINE 编排BDF Marker提取、筛查、人工分段和MAT导出。
%   日志默认开启；单文件读错由下层记录并跳过，配置错误直接停止。

    if nargin < 4 || isempty(logSwitch)
        logSwitch = "on";
    end

    [logFile, logEnabled] = ...
        HyperEEG.MultiCH.misc.InitLogFile([], "segment", logSwitch);

    if logEnabled
        diary(char(logFile));
        diary on
        diaryCleanup = onCleanup(@() closeDiary());
    end

    fprintf('[%s]', datestr(now,'yyyy-mm-dd HH:MM:SS'));
    fprintf("开始数据Marker切分流程\n");

    if nargin < 3 || isempty(DataIgnorePath)
        DataIgnorePath = "";
    end

    if ~exist(RawInputDir,"dir")
        error("RawInputDir不存在：%s", RawInputDir);
    end

    % 获取所有BDF文件
    files = HyperEEG.MultiCH.misc.getFiles(RawInputDir,"BDF");
    
    if isempty(files)
        error("RawInputDir中未找到任何BDF文件：%s", RawInputDir);
    end

    if ~exist(outputDir,"dir")
        mkdir(outputDir);
    end

    if ~isempty(DataIgnorePath)

        if ~isfile(DataIgnorePath)
            error("DataIgnorePath不存在：%s", DataIgnorePath);
        end
    
    end
    
    RawInputDir   = string(RawInputDir);
    outputDir     = string(outputDir);
    DataIgnorePath = string(DataIgnorePath);
    
    if ~endsWith(outputDir, filesep)
        outputDir = outputDir + filesep;
    end
    
    savekey.bool = 1;
    savekey.path = outputDir + 'segmentinfo.mat';
    
    fprintf('[%s]', datestr(now,'yyyy-mm-dd HH:MM:SS'));
    fprintf("正在进行marker提取\n");
    [markerList,errorFiles] = HyperEEG.MultiCH.main.MarkerList(RawInputDir);

    fprintf('[%s]', datestr(now,'yyyy-mm-dd HH:MM:SS'));
    fprintf("正在进行异常marker自动判别\n");
    flag = HyperEEG.MultiCH.main.MarkerCheck_Auto(markerList,errorFiles,DataIgnorePath);

    fprintf('[%s]', datestr(now,'yyyy-mm-dd HH:MM:SS'));
    fprintf("正在进行异常marker手动判别\n");
    segmentinfo = HyperEEG.MultiCH.main.MarkerCheck_Manual(flag,markerList,savekey);
    
    fprintf('[%s]', datestr(now,'yyyy-mm-dd HH:MM:SS'));
    fprintf("正在根据marker进行自动切割\n");
    HyperEEG.MultiCH.main.segment_Marker(segmentinfo,outputDir);
    
    clc;
    fprintf('[%s]', datestr(now,'yyyy-mm-dd HH:MM:SS'));
    fprintf("完成切分工作\n");

end

function closeDiary()
%CLOSEDIARY 确保Pipeline退出时关闭日志记录。

    diary off

end

function [logFile, logEnabled] = InitLogFile(path, name, logSwitch)
%INITLOGFILE Generate log file path and create log directory.
%
% Usage:
%   logFile = InitLogFile()
%   logFile = InitLogFile(path)
%   logFile = InitLogFile(path,name)
%   [logFile,logEnabled] = InitLogFile(path,name,logSwitch)

    %% 日志开关
    if nargin < 3 || isempty(logSwitch)
        logSwitch = "on";
    end

    if islogical(logSwitch) && isscalar(logSwitch)
        logEnabled = logSwitch;
    elseif isnumeric(logSwitch) && isscalar(logSwitch) && ...
            ismember(logSwitch, [0, 1])
        logEnabled = logical(logSwitch);
    elseif (ischar(logSwitch) || ...
            (isstring(logSwitch) && isscalar(logSwitch))) && ...
            any(strcmpi(string(logSwitch), ["on", "off"]))
        logEnabled = strcmpi(string(logSwitch), "on");
    else
        error("logSwitch必须为on、off、true或false。");
    end

    if ~logEnabled
        logFile = "";
        return;
    end

    %% 默认参数
    if nargin < 1 || isempty(path)
        path = fullfile(pwd, "log");
    end

    if nargin < 2 || isempty(name)
        name = "HyperEEG";
    end

    %% 创建文件夹
    if ~exist(path, "dir")
        mkdir(path);
    end

    %% 时间标签
    timeTag = datestr(now,'yyyymmdd_HHMMSS');

    %% 完整文件名：时间_工序
    logFile = fullfile(path, sprintf('%s_%s.txt', timeTag, name));

end

function logFile = InitLogFile(path, name)
%INITLOGFILE Generate log file path and create log directory.
%
% Usage:
%   logFile = InitLogFile()
%   logFile = InitLogFile(path)
%   logFile = InitLogFile(path,name)

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

    %% 完整文件名
    logFile = fullfile(path, sprintf('%s_%s.txt', name, timeTag));

end
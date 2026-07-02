%clc;
%clear all;

logFile = InitLogFile();


diary('logFile');
diary on

RawInputDir = 'I:\HyperEEG\data\脑电数据\8CH\raw';
DataIgnorePath = 'I:\HyperEEG\data\脑电数据\8CH\data_ignore.xlsx' ;
savekey.bool = 1;
savekey.path = 'I:\HyperEEG\data\脑电数据\8CH\spilt\segmentinfo.mat';
outputPath = '';


fprintf('[%s]', datestr(now,'yyyy-mm-dd HH:MM:SS'));
fprintf("正在进行marker提取\n");
%[markerList,errorFiles] = HyperEEG.MultiCH.main.MarkerList(RawInputDir);
fprintf('[%s]', datestr(now,'yyyy-mm-dd HH:MM:SS'));
fprintf("正在进行异常marker自动判别\n");
%flag = HyperEEG.MultiCH.main.MarkerCheck_Auto(markerList,errorFiles,DataIgnorePath);
fprintf('[%s]', datestr(now,'yyyy-mm-dd HH:MM:SS'));
fprintf("正在进行异常marker手动判别\n");
%[segmentindex,dataflag] = HyperEEG.MultiCH.main.MarkerCheck_Manual(flag,markerList,savekey);

load(savekey.path);

diary off


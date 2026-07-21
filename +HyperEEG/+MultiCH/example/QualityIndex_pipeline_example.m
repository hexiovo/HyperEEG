clc;
clear all;

%%==============================================================
% 数据质量索引：在所有清洗步骤结束后运行
%%==============================================================

% 四个阶段目录用于判断数据在哪一步被删除。
rawDir = 'I:\HyperEEG\data\脑电数据\8CH\raw';
segmentDir = 'I:\HyperEEG\data\脑电数据\8CH\spilt';
artifactDir = 'I:\HyperEEG\data\脑电数据\8CH\artifact';
cleanDir = 'I:\HyperEEG\data\脑电数据\8CH\clean';

% 日志开关："on"默认开启，日志写入项目log目录；测试时可用"off"。
logSwitch = "on";

[qualityTable,updatedFiles] = ...
    HyperEEG.MultiCH.pipeline.QualityIndex_pipeline( ...
    rawDir,segmentDir,artifactDir,cleanDir,logSwitch);

disp(qualityTable);
fprintf('已向%d个_clean.mat写入质量字段。\n',numel(updatedFiles));

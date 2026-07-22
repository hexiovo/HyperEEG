clc;
clear all;

RawInputDir = 'I:\HyperEEG\data\脑电数据\8CH\raw';
segmentoutputDir = 'I:\HyperEEG\data\脑电数据\8CH\spilt\';

% 两个XLSX示例与本脚本放在同一目录，可复制后替换其中示例文件名。
exampleDir = fileparts(mfilename('fullpath'));
DataIgnorePath = fullfile(exampleDir, 'data_ignore_example.xlsx');
SegmentPlanPath = fullfile(exampleDir, 'segment_plan_example.xlsx');

% 第5参数填写XLSX时批量导入；传入""则保留逐文件人工Marker界面。
HyperEEG.MultiCH.pipeline.segment_pipeline( ...
    RawInputDir, segmentoutputDir, DataIgnorePath, "on", SegmentPlanPath);

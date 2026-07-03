clc;
clear all;

segmentDir = 'I:\HyperEEG\data\脑电数据\8CH\spilt\';

outputDir = 'I:\HyperEEG\data\脑电数据\8CH\spilt\';

HyperEEG.MultiCH.pipeline.segment_pipeline(RawInputDir,outputDir,DataIgnorePath);


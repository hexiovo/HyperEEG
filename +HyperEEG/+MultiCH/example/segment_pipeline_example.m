clc;
clear all;

RawInputDir = 'I:\HyperEEG\data\脑电数据\8CH\raw';
DataIgnorePath = 'I:\HyperEEG\data\脑电数据\8CH\data_ignore.xlsx' ;
segmentoutputDir = 'I:\HyperEEG\data\脑电数据\8CH\spilt\';

HyperEEG.MultiCH.pipeline.segment_pipeline(RawInputDir,segmentoutputDir,DataIgnorePath);

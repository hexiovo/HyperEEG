clc;
clear all;

segmentInputDir = 'I:\HyperEEG\data\脑电数据\8CH\spilt\';
artifactoutputDir = 'I:\HyperEEG\data\脑电数据\8CH\artifact\';

if ~exist(artifactoutputDir, 'dir')
    mkdir(artifactoutputDir);
end

[outputFiles,excludedFiles] = ...
    HyperEEG.MultiCH.pipeline.Artifact_pipeline( ...
    segmentInputDir,artifactoutputDir);

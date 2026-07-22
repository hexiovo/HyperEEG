clc;
clear all;

% 可直接填写原始BDF目录，也可填写_segment.mat目录。
artifactInputDir = 'I:\HyperEEG\data\脑电数据\8CH\raw\';
artifactoutputDir = 'I:\HyperEEG\data\脑电数据\8CH\artifact\';

% "bdf"：连续BDF；"segment"：已分段MAT；"auto"：优先分段MAT。
options.inputType = "bdf";
options.auto.enabled = true;
options.manual.enabled = true;
options.apply.enabled = true;

if ~exist(artifactoutputDir, 'dir')
    mkdir(artifactoutputDir);
end

[outputFiles,excludedFiles] = ...
    HyperEEG.MultiCH.pipeline.Artifact_pipeline( ...
    artifactInputDir,artifactoutputDir,options,"on");

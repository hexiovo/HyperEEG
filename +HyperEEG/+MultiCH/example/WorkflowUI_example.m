clc;
clear;

% 推荐入口：显示单通道（待开发）与多通道模式选择器。
app = HyperEEG(); %#ok<NASGU>

% 如需跳过模式选择，可直接打开多通道统一工作流：
% app = HyperEEG.MultiCH.pipeline.WorkflowUI();

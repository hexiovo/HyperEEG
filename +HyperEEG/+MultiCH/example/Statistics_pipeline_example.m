clc;
clear;

% 输入目录中的MAT文件应包含EEGdata.data及采样率信息。
options.inputDir = "D:\HyperEEG\clean_data";
options.outputDir = "D:\HyperEEG\statistics";
options.groupFile = fullfile(fileparts(mfilename('fullpath')), ...
    'statistics_group_example.xlsx');
options.excelName = "time_domain_statistics";

% 仅列出需要计算的指标；MAT始终保存，XLSX布局单独控制。
options.timeDomain.metrics = ["mean", "median", "std", "mad", ...
    "rms", "line_length", "zero_cross_rate", ...
    "hjorth_activity", "hjorth_mobility", "hjorth_complexity"];
options.timeDomain.lineLengthNormalization = "per_sample";
options.timeDomain.quantileMethod = "linear";
options.timeDomain.madMethod = "median";
options.timeDomain.shapeBiasCorrection = "bias_corrected";
options.timeDomain.zeroCrossReference = "mean";
options.excel.enabled = true;
options.excel.timeDomainLayout = "both"; % wide / long / both / none
options.missing.method = "omit";
options.missing.maxFraction = 0.20;

summary = HyperEEG.MultiCH.pipeline.Statistics_pipeline(options); %#ok<NASGU>

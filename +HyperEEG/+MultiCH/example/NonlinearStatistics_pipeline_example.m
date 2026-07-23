clc;
clear;

options.inputDir = "D:\HyperEEG\clean_data";
options.outputDir = "D:\HyperEEG\statistics";
options.groupFile = fullfile(fileparts(mfilename('fullpath')), ...
    'statistics_group_example.xlsx');
options.excelName = "entropy_nonlinear_statistics";
options.timeDomain.enabled = false;
options.nonlinear.enabled = true;

% 5.3常用起始集合；RQA、相关维数和Lyapunov计算量较大，默认不选。
options.nonlinear.metrics = ["spectral_entropy", ...
    "differential_entropy", "sample_entropy", ...
    "approximate_entropy", "permutation_entropy", "lempel_ziv", ...
    "hurst", "dfa", "higuchi_fd", "petrosian_fd", "katz_fd"];
options.nonlinear.entropy.m = 2;
options.nonlinear.entropy.r = 0.2;
options.nonlinear.entropy.rMode = "std";
options.nonlinear.entropy.standardization = "zscore";
options.nonlinear.entropy.distance = "chebyshev";
options.nonlinear.spectral.method = "welch"; % welch / periodogram
options.nonlinear.differential.method = "gaussian"; % gaussian / histogram
options.nonlinear.maxSamples = 3000;
options.nonlinear.dfa.scaleMin = 16;
options.nonlinear.dfa.scaleMax = 512;
options.nonlinear.dfa.nScales = 12;
options.missing.method = "omit";

% 5.3标量与非标量序列分别控制XLSX布局；none表示只保留MAT。
options.excel.enabled = true;
options.excel.nonlinearScalarLayout = "wide"; % wide / long / both / none
options.excel.nonlinearSeriesMode = "long";   % long / wide / separate / none

% 启用RQA时，可将递归矩阵导出为递归点坐标或独立0/1稠密矩阵工作簿。
options.nonlinear.rqa.exportMatrixToExcel = false;
options.nonlinear.rqa.matrixExcelMode = "coordinates"; % coordinates / dense
options.excel.rqaLocation = "separate"; % coordinates可选main / separate

summary = HyperEEG.MultiCH.pipeline.Statistics_pipeline(options); %#ok<NASGU>

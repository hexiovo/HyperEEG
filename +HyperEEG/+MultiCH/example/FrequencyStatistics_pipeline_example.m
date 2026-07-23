%% 5.2 频谱与频带批处理示例
% 修改路径后运行。仅保存MAT时将options.excel.enabled设为false。

options.inputDir = "D:\HyperEEG\clean_data";
options.outputDir = "D:\HyperEEG\statistics";
options.groupFile = fullfile(fileparts(mfilename('fullpath')), ...
    'statistics_group_example.xlsx');
options.excelName = "frequency_band_statistics";

options.timeDomain.enabled = false;
options.frequency.enabled = true;
options.nonlinear.enabled = false;
options.frequency.metrics = ["psd", "absolute_power", ...
    "relative_power", "log_power", "spectral_shape", ...
    "spectral_edge", "individual_alpha_peak", "spectral_flatness", ...
    "aperiodic", "faa"];

% Welch与频带定义
options.frequency.welch.windowSeconds = 2;
options.frequency.welch.overlap = 0.5;
options.frequency.welch.nfft = 512;
options.frequency.bands.names = ["delta", "theta", "alpha", ...
    "beta", "gamma"];
options.frequency.bands.rangesHz = [1 4; 4 8; 8 13; 13 30; 30 45];
options.frequency.totalRangeHz = [1 45];

% FAA：右侧log-alpha减左侧log-alpha
options.frequency.faa.pairs = ["F3", "F4"; "F7", "F8"];
options.frequency.faa.direction = "right_minus_left";
options.frequency.faa.transform = "natural_log";

% PSD与周期峰分别设置XLSX布局：long / wide / separate / none
options.excel.enabled = true;
options.excel.psdMode = "long";
options.excel.spectrumStride = 1; % 1=导出全部频点；不影响MAT
options.excel.periodicPeakMode = "wide";

summary = HyperEEG.MultiCH.pipeline.Statistics_pipeline(options);
disp(summary.excelPaths);

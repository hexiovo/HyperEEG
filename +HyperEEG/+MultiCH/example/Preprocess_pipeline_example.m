clc;
clear all;

%%==============================================================
% 输入、输出与日志
%%==============================================================

% 输入目录：只读取目录及子目录中的_artifact.mat文件。
artifactInputDir = 'I:\HyperEEG\data\脑电数据\8CH\artifact\';

% 可选"auto"、"bdf"、"artifact"或"segment"；统一UI会自动设置。
options.inputType = "artifact";

% 输出目录：结果保存为_clean.mat；建议与artifact目录分开。
cleanOutputDir = 'I:\HyperEEG\data\脑电数据\8CH\clean\';

% 日志开关："on"或"off"；通常保持"on"便于追溯。
logSwitch = "on";

if ~exist(cleanOutputDir, 'dir')
    mkdir(cleanOutputDir);
end

%%==============================================================
% 1. 重采样（可选）
%%==============================================================

% true：执行重采样；false：保持原采样率。
% 原采样率较高、数据量较大且目标频率较低时可开启。
options.resample.enabled = true;

% 目标采样率，单位Hz。常见值：128、250、256、500。
% 目标采样率至少应高于最高分析频率的2倍，实际建议留出余量。
% 例如分析1–45 Hz连接指标时，250 Hz通常足够。
options.resample.targetRate = 250;

%%==============================================================
% 2. 去趋势
%%==============================================================

% 通常开启，用于减少直流偏置和缓慢线性漂移。
options.detrend.enabled = true;

% "linear"：去除线性趋势，适合连续记录，默认推荐。
% "constant"：只去均值，不去除随时间变化的线性漂移。
options.detrend.method = "linear";

%%==============================================================
% 3. 带通滤波
%%==============================================================

% 通常开启；具体频率必须根据最终指标预先确定。
options.bandpass.enabled = true;

% 常用预设：
% "broadband"      = [0.5,80] Hz，通用宽频分析；
% "connectivity"   = [1,45] Hz，常用连接/同步指标；
% "erp"            = [0.1,30] Hz，慢成分和ERP；
% "time_frequency" = [1,80] Hz，时频分析；
% "slow"           = [0.1,15] Hz，慢波研究；
% "custom"         = 使用下方rangeHz。
options.bandpass.profile = "connectivity";

% 自定义频率范围，单位Hz，例如[1,40]。
% []表示使用profile预设；非空时会覆盖profile对应的范围。
options.bandpass.rangeHz = [];

% Butterworth阶数。常见值2–4；阶数越高过渡越陡，
% 但短片段和边缘更容易出现不稳定，通常使用4。
options.bandpass.order = 4;

%%==============================================================
% 4. 工频滤波
%%==============================================================

% 中国大陆通常为50 Hz；若带通上限低于50 Hz，影响通常较小。
options.notch.enabled = true;

% 工频中心，单位Hz。中国大陆/欧洲常用50，美国常用60。
options.notch.lineFrequencyHz = 50;

% 阻带总宽度，单位Hz。常见值1–4，默认2即49–51 Hz。
options.notch.bandwidthHz = 2;

% Butterworth阶数。常见值2–4；默认2以减少过度滤波。
options.notch.order = 2;

%%==============================================================
% 5. 重参考（不是所有数据都必须执行）
%%==============================================================

% 没有明确参考电极、参考方案不清楚或只有少量通道时建议false。
% 做源定位、明确要求平均参考，或各数据参考方案需要统一时再开启。
options.reference.enabled = false;

% "median"：通道中位数参考，对异常通道更稳健；
% "average"：平均参考，通常更适合覆盖较均匀且通道较多的数据；
% "channel"：使用channels指定的一个或多个通道作参考；
% "none"：不改变数据。
% 注意：当前流程重参考位于ICA之前；若自动方法包含ICA，不要选择
% 非线性的median，请关闭重参考或改用average/channel。
options.reference.method = "median";

% []表示使用全部通道；也可填写[1,2]等指定参考通道。
% method="channel"时必须根据实际电极布局指定，不要随意填写。
options.reference.channels = [];

%%==============================================================
% 6. 自动伪迹处理
%%==============================================================

% 总开关。false时自动和人工两个伪迹步骤都跳过。
options.artifact.enabled = true;

% 自动处理开关。
options.artifact.auto.enabled = true;

% 自动方法可为"robust"、"asr"、"ica"或"none"。
% 也支持按顺序填写多个，例如["robust","asr"]，但连续运行多种
% 方法会重复修改信号，不能因为“方法更多”就认为结果更可靠。
% 当前默认按顺序执行robust+ASR、人工ICA、最终通道频域复核。
% robust先处理孤立极端值，ASR再修复较长的高振幅瞬态。
% 如果必须在ICA和ASR中二选一：长连续记录优先试ASR；8通道ICA
% 成分太少，通常不作为默认方案。无论选择哪种都仍需人工复核。
options.artifact.auto.methods = ["robust", "asr"];

% robust阈值。常见值6–10；越小越严格。
% 8通道、干电极或头动较多时建议先用8，避免过度修复。
options.artifact.auto.robustZ = 8;

% robust局部窗口长度，单位秒。常见值0.5–2；默认1秒。
options.artifact.auto.robustWindow_s = 1;

% ICA成分峰度阈值。常见值4–8；越小拒绝越多。
% ICA更适合通道较多、记录较长且数据秩充足的情况。
options.artifact.auto.icaKurtosisZ = 6;

% ICA高频变化阈值。常见值4–8，用于辅助识别快速肌电成分。
options.artifact.auto.icaHighFrequencyZ = 6;

% ICA最多自动删除的成分比例。常见值0.1–0.25。
% 8通道数据不建议设置过高。
options.artifact.auto.icaMaxRejectFraction = 0.25;

% 明确知道坏成分序号时可填写，如[1,3]；[]表示自动判断。
options.artifact.auto.icaRejectComponents = [];

% 长连续记录最多用多少采样点训练自动ICA；权重仍应用于完整数据。
options.artifact.auto.icaMaxTrainingSamples = 100000;

% ASR BurstCriterion。常见值10–30；越小越严格。
% 20是clean_rawdata常用的保守起点。ASR需要足够长的数据和
% 相对干净的校准片段；8通道可以试用，但必须人工检查处理前后。
options.artifact.auto.asrBurstCriterion = 20;

% ASR最大内存，单位MB。常见值256、512、1024。
options.artifact.auto.asrMaxMemoryMB = 512;

%%==============================================================
% 7. 人工ICA成分复核
%%==============================================================

% true：ASR后计算ICA并打开成分界面；逐个查看时间序列、频谱和
% 通道权重，再人工标记明确的眼动、心电、肌电或电极噪声成分。
% 常规值为true/false。8通道分离证据有限，不确定的成分应保留；
% 可以确认空选择。取消会跳过当前文件且不保存半成品。
options.artifact.icaManual.enabled = true;

% 人工ICA模型最大训练点数。默认100000可显著减少长记录等待时间。
options.artifact.icaManual.maxTrainingSamples = 100000;

%%==============================================================
% 8. 最终人工通道频域复核
%%==============================================================

% true：ICA确认后显示通道×频率(Hz) PSD热图；false：跳过。
% 可用上下按钮切换通道、标记整条坏导、记录通道特定可疑频段或排除整文件。
% 点击左下PSD可读取精确Hz。新增整条坏导时会从首次ICA前数据恢复，
% 屏蔽累计坏导并对剩余通道重启ICA，直到没有新增坏导；可疑频段不触发。
% 对8通道数据，推荐开启；如果输入_artifact.mat已经充分人工复核，
% 且不需要检查自动处理后的波形，也可以关闭以避免重复操作。
options.artifact.manual.enabled = true;

%%==============================================================
% 执行Pipeline
%%==============================================================

outputFiles = HyperEEG.MultiCH.pipeline.Preprocess_pipeline( ...
    artifactInputDir,cleanOutputDir,options,logSwitch);

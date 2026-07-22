# Function Document
**本说明将按章节对各部分涉及的函数进行说明。**

## 顶层启动器
```matlab
app = HyperEEG()
```
类似`eeglab`的项目入口。显示单通道和多通道选项；单通道入口当前禁用并标记待开发，多通道进入`HyperEEG.MultiCH.pipeline.WorkflowUI`。

无输出调用`HyperEEG`会打印名称、V0.5.5版本、版权、依赖环境和注意事项，不产生`ans`；显式调用`app = HyperEEG()`仍返回UI句柄和控件结构，便于脚本或测试控制。

## Content
- [Pipeline](#Pipeline)
  - [WorkflowUI](#WorkflowUI)
  - [Workflow_pipeline](#Workflow_pipeline)
  - [segment_pipeline](#segment_pipeline)
  - [Artifact_pipeline](#Artifact_pipeline)
  - [Preprocess_pipeline](#Preprocess_pipeline)

- [Main](#Main)
  - [WorkflowOptions](#WorkflowOptions)
  - [ArtifactOptions](#ArtifactOptions)
  - [segment_EEGdata](#segment_EEGdata)
  - [MarkerExtract](#MarkerExtract)
  - [MarkerList](#MarkerList)
  - [MarkerSegmentEditor](#MarkerSegmentEditor)
  - [MarkerCheck_Auto](#MarkerCheck_Auto)
  - [MarkerCheck_Manual](#MarkerCheck_Manual)
  - [segment_Marker](#segment_Marker)
  - [PlotEEGData](#PlotEEGData)
  - [SegmentEditor](#SegmentEditor)
  - [DataArtifact_segment](#DataArtifact_segment)
  - [DataArtifact_Auto](#DataArtifact_Auto)
  - [DataArtifact_Manual](#DataArtifact_Manual)
  - [PreprocessOptions](#PreprocessOptions)
  - [DataPreprocess functions](#DataPreprocess-functions)
  - [FrequencyReviewEditor](#FrequencyReviewEditor)
  - [QualityIndex_pipeline](#QualityIndex_pipeline)
- [core](#Core)
  - [EEGdataFromBDF](#EEGdataFromBDF)
  - [BDFreader](#BDFreader)
  - [Marker_CheckByCount](#Marker_CheckByCount)
  - [EEGdataSaver](#EEGdataSaver)
  - [ProcessStatus](#ProcessStatus)
  - [ArtifactDetectByWindow](#ArtifactDetectByWindow)
  - [Preprocess core functions](#Preprocess-core-functions)
  - [PreprocessChannelSpectrum](#PreprocessChannelSpectrum)
- [misc](#Misc)
  - [getFiles](#getFiles)
  - [Segmentmerge](#Segmentmerge)
  - [InitLogFile](#InitLogFile)
  - [BackfillProcessStatus](#BackfillProcessStatus)




## Pipeline
**本部分为集成函数，调用后续函数进行处理**

### WorkflowUI
```matlab
app = HyperEEG.MultiCH.pipeline.WorkflowUI()
```
打开统一工作流界面。四个页签分别配置流程与路径、坏段全部参数、预处理全部参数和运行日志。底部“运行：先分段”和“运行：先预处理”是两个独立入口；“统计分析（待开发）”为禁用占位按钮。测试或嵌入调用可传入`'Visible','off'`。

各配置页使用MATLAB R2023a原生可滚动的`uigridlayout`，按固定行高完整呈现参数并随窗口宽度伸缩。运行中点击关闭会弹出取消确认；确认后通过`WorkflowCancel`向各Pipeline发送协作式取消请求，关闭当前人工复核窗口并保留主UI。

底部“打开操作说明”按钮使用项目根目录解析并通过系统PDF阅读器打开`txt/HyperEEG全流程操作说明.pdf`。运行异常会将`getReport`完整堆栈写入界面日志，而不只显示一行错误消息。

### Workflow_pipeline
```matlab
results = Workflow_pipeline(config,order,progressCallback)
```
不依赖UI的工作流编排入口。`order`取`"segment_first"`或`"preprocess_first"`。前者兼容原顺序；后者先在连续BDF上执行坏段和预处理，再调用`segment_EEGdata`切割清洗后的连续MAT，从而避免每个小段重复人工ICA。`config`由`WorkflowOptions`补齐和验证，第三参数可选，用于接收阶段进度文本。

### segment_pipeline
```matlab
segmentinfo = segment_pipeline( ...
    RawInputDir,outputDir,DataIgnorePath,logSwitch, ...
    SegmentPlanPath,executeSegment)
```
完成从数据输入到根据marker分割的全过程。其中：

`SegmentPlanPath`为可选的`.xlsx`批量分段计划。`executeSegment`默认为`true`；设为`false`时只生成并保存`segmentinfo`，供“先预处理”流程最后切割清洗数据。填写XLSX后跳过逐文件人工输入，并且不再使用“不同文件Marker数量离群”排除文件；读取失败和`DataIgnorePath`仍然生效。留空或省略时保持原交互流程。XLSX优先读取`segments`工作表，否则读取第一个工作表；每行表示一个区间，必需列如下：

| 列 | 含义 |
|---|---|
| `file_name` | BDF文件名、相对路径或完整路径；仅写文件名时必须唯一 |
| `segment_name` | 输出分段名；同名多行表示同一分段的多个区间 |
| `start` | 区间开始位置 |
| `end` | 区间结束位置，也可填`end`表示数据末尾 |
| `unit` | `time_ms`、`time_s`或`sample_index`，不得省略 |

可选列`enabled`填写1/0、true/false或是/否；禁用行不导入。`notes`可用于人工备注但不参与计算。导入后所有边界统一转换为相对EEG时间轴的`time_ms`并写入`segmentinfo.source`追溯来源。
```matlab
RawInputDir:原始BDF文件存储地址
outputDir:目标输入地址，不能与上述等同
DataIgnorePath:需要忽视的数据名，格式为列数据，首行为表头，任意填写，如：姓名。下方为各自数据的对应名称。
logSwitch:日志开关，可填写"on"或"off"，默认值为"on"。
```
data_ignore.xlsx文件格式如下：
| 名称 | |  |
|:---:|:---:|:--:|
| 001  |   |   |
| 002  |   |   |

### Artifact_pipeline
```matlab
[outputFiles,excludedFiles] = Artifact_pipeline( ...
    inputDir,outputDir,autoOptions,logSwitch)
```
读取`inputDir`及其子目录中的原始BDF或`_segment.mat`，依次完成自动坏段识别、人工坏段复核、统一切割与MAT保存。`autoOptions.inputType`可为`"auto"`、`"bdf"`或`"segment"`；`autoOptions.auto.enabled`、`manual.enabled`和`apply.enabled`分别控制自动检测、人工复核和实际应用标记。其余窗口检测参数统一由`ArtifactOptions`补齐。`logSwitch`可为`"on"`或`"off"`。`outputFiles`返回成功生成的文件，`excludedFiles`返回人工判定整文件无效的输入文件。

自动和人工函数只返回标记，不直接修改数据。Pipeline将标记分别写入`EEGdata.artifact.auto`和`EEGdata.artifact.manual`，再统一调用`DataArtifact_segment`处理。`channel = 0`表示删除所有通道共同的坏时间列；`channel > 0`只将指定通道对应区间设为`NaN`。输出文件保存在`outputDir`，文件名末尾由`_segment.mat`改为`_artifact.mat`。处理日志与`segment_pipeline`统一保存在当前工作目录的`log`文件夹，文件名格式为`时间_artifact.txt`。用户取消人工复核时跳过当前文件且不保存。

### Preprocess_pipeline
```matlab
outputFiles = Preprocess_pipeline(inputDir,outputDir,options,logSwitch)
```
读取`inputDir`及其子目录中的BDF、`_segment.mat`或`_artifact.mat`，按顺序执行可选重采样、去趋势、带通滤波、工频滤波、重参考和伪迹处理。`options.inputType`可为`"auto"`、`"bdf"`、`"segment"`或`"artifact"`。每一步均由`main`层独立函数封装，核心计算位于`core`层。输出保存在`outputDir`并以`_clean.mat`结尾，成功保存的完整路径由`outputFiles`返回。

`logSwitch`默认值为`"on"`，日志保存在当前工作目录的`log`文件夹，名称格式为`时间_preprocess.txt`。每一步的参数、执行时间、输入/输出样本数和MATLAB版本写入`EEGdata.preprocessing.history`；当前采样率写入`EEGdata.etc.samplerate.clean`，输出路径写入`EEGdata.file.cleanpath`。

默认参数为不重采样、不重参考、线性去趋势、0.5–80 Hz带通、50 Hz Notch、按顺序执行`robust + ASR`、人工ICA成分选择和最终通道频域复核。最终复核显示通道×频率(Hz) PSD，不生成时频图；可以标记整条坏导或排除整文件。

人工和自动ICA分别通过`artifact.icaManual.maxTrainingSamples`与`artifact.auto.icaMaxTrainingSamples`限制模型训练点数，默认100000。长记录均匀抽样估计ICA权重，再把权重应用于完整连续数据；不会截短最终信号。



## Main
**本部分为数据处理的封装函数，用于调用算法以及各种子集函数，实现单一功能**

### WorkflowOptions
递归补齐统一UI和`Workflow_pipeline`配置，验证阶段开关、日志开关，并分别调用`ArtifactOptions`和`PreprocessOptions`完成子配置校验。

### ArtifactOptions
集中定义`Artifact_pipeline`的输入类型、自动/人工/应用三个开关及全部滑窗坏段检测参数；错误参数会在批处理读取文件前终止。

### segment_EEGdata
```matlab
outputFiles = segment_EEGdata(segmentinfo,inputDir,outputDir)
```
按`time_ms`分段计划切割连续`_artifact.mat`或`_clean.mat`，保留已有预处理数据、处理历史和状态，输出`_artifact_segment.mat`或`_clean_segment.mat`。用于连续优先流程，不重新运行坏段、ASR或ICA。
### MarkerExtract
```matlab
marker = MarkerExtract(filename)
```
读取指定BDF文件，并返回其中的marker，用于后续筛选分段数据

### MarkerList
```matlab
[markerList,errorFiles] = MarkerList(inputDir)
```
读取指定路径下的所有BDF文件，并返回其中的marker，用于后续筛选分段数据，调用MarkerExtract

### MarkerSegmentEditor
```matlab
[outmarker , emptybool] = MarkerSegmentEditor(markerdata)
```
传入包含`type`、`sample_index`和`time_ms`的Marker列，弹出分段编辑界面。Sample index和Time (ms)均按完整整数显示，不使用科学计数法；毫秒四舍五入且不保留小数。Start和End统一填写time_ms。返回人工分段及是否取消，取消时`emptybool = 1`。

### MarkerCheck_Auto
```matlab
dataflag = MarkerCheck_Auto(markerList,errorFiles,DataIgnorePath)
```
对传入的maeker列进行自动识别，识别过长过短项目，并且读取外在的DataIgnorePath，如果存在则进行flag的添加。

### MarkerCheck_Manual
```matlab
segmentinfo = MarkerCheck_Manual(dataflag,markerList,savekey)
```
对传入的maeker列进行人工注意判别，注意进行，并进行merge操作，如果存在savekey，则进行保存。
```matlab
%savekey标准格式为：
savekey.bool=1;
savekey.path = filepath(以.mat结尾)
```

### segment_Marker
```matlab
segment_Marker(segmentinfo,outputDir)
```
根据前面输入的相关信息进行切割，保存有用信息。


### PlotEEGData
```matlab
PlotEEGData(EEGdata,nSeg)
```
绘制EEGData的线形图

### SegmentEditor
```matlab
[outsegment, emptybool] = SegmentEditor(EEGdata,currentfilename,nSeg)
```
显示当前数据并收集人工坏通道区间。表格中的`Channel`填写0到通道总数之间的整数，`Start`和`End`使用`EEGdata.times`的时间单位；`Channel = 0`表示全部通道，`Channel > 0`表示指定通道。只填写`Channel > 0`表示整条指定通道为坏导；只填写`Channel = 0`表示整个文件无效，提交前再次确认，Pipeline随后整文件排除且不生成后续阶段文件，原始输入文件保持不变。

### DataArtifact_segment
```matlab
[EEGdata,removedSampleCount,maskedValueCount] = DataArtifact_segment(EEGdata,outsegment)
```
根据`channel`和时间区间处理坏段。`channel = 0`表示全局坏段，会同时删除`EEGdata.times`及所有通道中的对应时间列，并通过`removedSampleCount`返回删除列数；`channel > 0`表示人工通道标记，只将指定通道区间设为`NaN`，保持所有通道共享同一时间轴，并通过`maskedValueCount`返回屏蔽的数据值数量。输入为空时不修改数据。函数只负责处理，不负责识别、写入artifact标记或保存文件。

### DataArtifact_Auto
```matlab
[outsegment,emptybool] = DataArtifact_Auto(EEGdata,options)
```
在人工坏段复核前进行自动初筛。函数只调用`ArtifactDetectByWindow`并返回自动坏段标记，不修改`EEGdata`、不执行切割，也不保存文件。未识别到坏段时`emptybool = 1`。`options`可省略，标记和切割由`Artifact_pipeline`统一处理。

默认使用2秒、50%重叠窗口，并综合峰峰值、突跳、一阶差分高频比、平线和多通道协方差几何距离。普通异常需要多个指标或多个通道共同支持，只有极端异常可由单指标直接触发，因此默认设置偏向保留数据。常用参数如下：

```matlab
options.sampleRate = 采样率;             % EEGdata中缺少采样率时必填
options.windowDuration_s = 2;
options.windowOverlap = 0.5;
options.robustZThreshold = 6;
options.severeZThreshold = 10;
options.minMetricVotes = 2;
options.minBadChannelRatio = 0.25;
options.covarianceZThreshold = 6;
options.mergeGap_s = 0.25;
```


### DataArtifact_Manual
```matlab
[outsegment,cancelbool,excludeFileBool] = ...
    DataArtifact_Manual(EEGdata,currentfilename)
```
显示当前EEG数据并收集人工坏通道区间，返回结构中的`channel`为通道序号。函数不修改`EEGdata`、不执行切割，也不保存文件。用户取消时`cancelbool = 1`；正常确认但未标记时返回空结构体且`cancelbool = 0`；`Channel=0`覆盖全部数据时`excludeFileBool=1`。`currentfilename`只用于界面显示，可省略。

### PreprocessOptions
```matlab
options = PreprocessOptions(userOptions)
```
合并预处理默认参数与用户参数。常用配置如下：

```matlab
options.resample.enabled = false;
options.resample.targetRate = 250;
options.detrend.enabled = true;
options.detrend.method = "linear";       % linear或constant
options.bandpass.enabled = true;
options.bandpass.profile = "broadband"; % broadband/connectivity/erp/
                                         % time_frequency/slow/custom
options.bandpass.rangeHz = [];           % 非空时覆盖profile
options.notch.enabled = true;
options.notch.lineFrequencyHz = 50;
options.reference.enabled = false;
options.reference.method = "median";    % median/average/channel/none
options.artifact.enabled = true;
options.artifact.auto.enabled = true;
options.artifact.auto.methods = ["robust","asr"];
options.artifact.icaManual.enabled = true;
options.artifact.manual.enabled = true;
```

带通预设依次为：`broadband=[0.5,80] Hz`、`connectivity=[1,45] Hz`、`erp=[0.1,30] Hz`、`time_frequency=[1,80] Hz`和`slow=[0.1,15] Hz`。最高频率超过当前Nyquist频率时会安全收窄，并在处理历史中记录实际频率范围。研究分析前仍应根据目标指标固定参数，不应在看到结果后选择滤波范围。

后处理重参考不是必选步骤。参考信息不明确或通道较少时建议保持关闭；自动方法包含ICA时，当前Pipeline禁止在ICA之前使用非线性的`median`参考，可关闭重参考或改用`average/channel`。

### DataPreprocess functions
```matlab
[EEGdata,info] = DataPreprocess_Resample(EEGdata,options)
[EEGdata,info] = DataPreprocess_Detrend(EEGdata,options)
[EEGdata,info] = DataPreprocess_Bandpass(EEGdata,options)
[EEGdata,info] = DataPreprocess_Notch(EEGdata,options)
[EEGdata,info] = DataPreprocess_Reference(EEGdata,options)
[EEGdata,info] = DataPreprocess_ArtifactAuto(EEGdata,options)
[EEGdata,info,cancelbool] = DataPreprocess_ArtifactICAManual( ...
    EEGdata,currentfilename,options)
[EEGdata,info,cancelbool,excludeFileBool,rerunICABool] = ...
    DataPreprocess_ArtifactManual( ...
    EEGdata,currentfilename,allowRerunICA)
```
以上函数分别封装单一预处理步骤。默认自动顺序为`robust + ASR`；其后人工ICA界面逐个显示成分时间序列、成分PSD和通道权重。最后人工函数调用独立频域复核界面，显示清洗后信号的通道×频率(Hz) PSD，可标记整条坏导、返回上一步重新ICA或排除整文件；结果写入`EEGdata.artifact.frequencyManual`。任一人工步骤取消时`cancelbool=1`，请求重新ICA时`rerunICABool=1`。`allowRerunICA`省略时默认为`true`；Pipeline会根据人工ICA开关传入实际值。

### FrequencyReviewEditor
```matlab
[reviewResult,cancelbool,excludeFileBool,rerunICABool] = ...
    FrequencyReviewEditor(EEGdata,currentfilename,allowRerunICA)
```
用于预处理最后一步人工复核，不替代Artifact阶段的时域坏段界面。可通过上下按钮逐通道查看PSD；点击左下曲线显示最近频率点的精确Hz。支持标记整条坏导或可疑频段。点击“退回上一步，重新ICA”时，本轮尚未确认的坏导和频段标记会被放弃，Pipeline恢复首次人工ICA前信号并重新打开ICA成分界面；此前已确认的坏导仍保持屏蔽。新增整条坏导后也会自动按相同基线重启ICA，直到没有新增坏导；可疑频段不触发重跑。人工ICA关闭时重新ICA按钮禁用。

### QualityIndex_pipeline
```matlab
[qualityTable,updatedFiles] = QualityIndex_pipeline( ...
    rawDir,segmentDir,artifactDir,cleanDir,logSwitch)
```
全部处理结束后扫描raw、segment、artifact和clean四个目录。存在可读取`_clean.mat`时`qualityTable.isValid=1`；否则根据最晚存在的阶段写入`数据切分阶段删除`、`坏段处理阶段删除`或`预处理阶段删除`。有效数据会调用`DataQualitySummary`，结果只写入`EEGdata.quality`：`badchannel`保存整条排除的坏导，`channelrate`为N×2 cell（左列为`ch1`等通道名，右列为0到1的数值比例），总体比例保存为`totalEffectiveRate`。`updatedFiles`返回被补写质量字段的MAT文件。Excel清单属于项目数据管理，不由包内函数写入。


## Core

### EEGdataFromBDF
```matlab
EEGdata = EEGdataFromBDF(filepath)
```
把单份BDF读取为连续`EEGdata`，不做信号修改和分段；保留原始路径、事件样本索引，并新增显式`time_ms`。供坏段和预处理Pipeline直接接受BDF时复用。
**本部分为底层计算函数，实现单一功能，若需要进行修改，这部分是核心修改内容**
### BDFreader
```matlab
EEG = BDFreader(inputDir);
```
用于读取制定输入路径的BDF文件并返回。
接受string和char两种模式的输入，最终转换为char格式，这是为了适应biosig的读取规则（只接受char路径），如有变动请自行修改。


### Marker_CheckByCount
```matlab
abnormalidx = Marker_CheckByCount(markercount)
```
用于根据输入的marker长度序列返回明显异常值，若无则返回空集


### EEGdataSaver
```matlab
EEGdata = EEGdataSaver(EEGdata,BDFdata)
```
读取对应BDFdata中的信息，存储到EEGdata的.mat文件中，设置为CORE的主要原因是便于拓展，若设备存在更多可导出信息，且有需要，可在此处进行调整，后续读取即可。

### ProcessStatus
```matlab
EEGdata = ProcessStatus(EEGdata)
EEGdata = ProcessStatus(EEGdata,processName,processValue)
```
集中维护`EEGdata.Process`。无步骤参数时补齐全部已知字段并将缺失字段初始化为0；指定步骤后写入0或1。Pipeline只在操作真正成功后写1，关闭、跳过、取消和异常保持0。状态覆盖BDF读取、Marker提取与复核、XLSX Marker导入、分段、坏段自动/人工处理、重采样、去趋势、带通、Notch、重参考、robust、ASR、自动/人工ICA、最终人工复核和预处理完成。人工录入成功写`marker_manual=1`；XLSX导入成功写`marker_import=1`。`ica`是所有ICA操作的汇总状态，`ica_auto`和`ica_manual`用于区分方式；ASR字段使用标准拼写`asr`。

### ArtifactDetectByWindow
```matlab
[badIntervals,detectionInfo] = ArtifactDetectByWindow(EEGdata,options)
```
自动坏段识别的核心函数，不负责保存文件或修改原始输入。该函数在各通道内部使用中位数和MAD计算稳健异常分数，通过多指标投票减少单阈值误删；多通道数据还会比较正则化协方差矩阵的对数几何距离，以识别振幅不一定极端、但通道联合分布明显改变的窗口。检测会识别`EEGdata.times`中的不连续区间，不跨原有片段建立或合并窗口。返回的`badIntervals`单位和时间基准与`EEGdata.times`完全一致。

### Preprocess core functions
```matlab
[data,times,info] = PreprocessResample(...)
[data,info] = PreprocessDetrend(...)
[data,info] = PreprocessBandpass(...)
[data,info] = PreprocessNotch(...)
[data,info] = PreprocessReference(...)
[data,info] = PreprocessArtifact(...)
sampleRate = PreprocessSampleRate(EEGdata)
blocks = PreprocessContinuousBlocks(timeValues)
```
这些函数实现与UI、文件读写无关的核心计算。重采样使用抗混叠多相FIR；带通和Notch使用零相位Butterworth滤波；伪迹核心根据`method`分派到鲁棒修复、ICA或ASR。`PreprocessFillMissing`只作为各算法的临时计算辅助，不会永久填补原有人工坏通道标记。

### PreprocessChannelSpectrum
```matlab
[frequencyHz,powerDb] = PreprocessChannelSpectrum( ...
    data,timeValues,sampleRate)
```
计算最终复核所需的通道×频率PSD。输出`powerDb`尺寸为通道数×频率点数，`frequencyHz`单位Hz；存在已删除时间段时按连续块分别估计并按有效样本数加权，不跨时间缺口计算频谱。



## Misc
**本部分为底层处理函数，实现单一功能，主要是负责进行包装，文件读取等。**
### getFiles
```matlab
filePaths = getFiles(rootPath, ext)
```
递归获取指定后缀文件

### Segmentmerge
```matlab
segmentInterval = Segmentmerge(segmentindex)
```
对输入的segment进行合并，合并成可用的数值段

### InitLogFile
```matlab
[logFile,logEnabled] = InitLogFile(path,name,logSwitch)
```
生成初始log日志文件，默认保存在当前工作目录的`log`文件夹。文件名格式为`时间_工序.txt`，`path`和`name`均可自定义。`logSwitch`默认值为`"on"`；设置为`"off"`、`false`或`0`时，返回空路径且不创建日志文件夹。

### BackfillProcessStatus
```matlab
[updatedFiles,failedFiles] = BackfillProcessStatus(inputDir,dataStage)
```
为旧版`_segment.mat`或`_artifact.mat`批量补写`EEGdata.Process`。`dataStage`填写`"segment"`或`"artifact"`。函数只处理对应后缀，先在同目录建立临时副本、写入并验证，再替换原文件；EEG数据本体、文件名和其它MAT变量保持不变。

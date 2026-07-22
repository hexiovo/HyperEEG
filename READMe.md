# HyperEEG---lecture-Paradigm
notice:本项目仅适用于多人无互动学习范式，其具有高度的特异性，如需迁移，请在看懂本包的基础上做适当调整。

authority：[hexi](https://github.com/hexiovo)

email：[彭洋](mailto:py_edu_mail@163.com)

完整的逐步运行方法、人工界面判断准则和输出验收清单见`txt/HyperEEG全流程操作说明.pdf`；PDF提供可点击目录、书签和实际操作界面截图。

# 统一工作流界面

推荐从项目根目录直接运行：

```matlab
HyperEEG
```

启动窗口提供“单通道”和“多通道”两个入口；单通道当前灰显待开发，点击多通道进入完整工作流。也可跳过启动窗口直接运行：

直接输入`HyperEEG`时，命令行会显示平台名称、版本、版权、运行环境和注意事项，不再生成或显示`ans`结构体。如需在脚本中控制启动窗口，仍可显式接收返回值：`app = HyperEEG();`。

```matlab
app = HyperEEG.MultiCH.pipeline.WorkflowUI();
```

界面包含“流程与路径”“坏段参数”“预处理参数”“运行日志”四页，所有正式步骤都有启用开关，坏段检测和预处理的全部现有参数均可配置。底部提供两个独立入口：

- `运行：先分段`：BDF → `_segment.mat` → `_artifact.mat` → `_clean.mat`，兼容原流程，但每个片段可能分别进行人工ICA；
- `运行：先预处理`：连续BDF → `_artifact.mat` → `_clean.mat` → 最终`_clean_segment.mat`。ICA在每份长连续记录上执行一次，再按Marker计划切段，通常更适合当前问题；
- `统计分析（待开发）`：已预留并禁用，当前版本不会执行未定义的统计方法。

原始BDF始终只读，各阶段必须使用不同输出目录。可继续传入示例中的`segment_plan_example.xlsx`与`data_ignore_example.xlsx`。

人工坏段复核没有新增标记时，保持表格为空并点击“确认（可无新增坏段）”；关闭窗口或点击取消表示跳过当前文件。连续人工ICA默认最多均匀选取100000个采样点估计权重，再把权重应用到完整记录，并显示“ICA计算中”窗口；可在“预处理参数 → 人工复核”调整最大训练点数。

流程与路径、坏段参数、信号步骤、自动伪迹、人工复核和运行日志页面均使用独立垂直滚动区，窗口缩小时不会截断下方参数。任务运行期间点击主界面的“关闭”或右上角关闭键，会先询问是否取消；确认后协作式停止当前任务并保留界面与已填写参数，不会直接关闭UI。

多通道主界面底部的“打开操作说明”可直接打开`txt/HyperEEG全流程操作说明.pdf`。V0.5.3同时修复了先预处理流程在最终分段时将`string`路径错误传入`dir`的问题，并兼容空的忽略名单路径；V0.5.4将原TXT重排为正式PDF手册；V0.5.5补充实际操作界面截图，并统一Marker整数显示。

# 0 Prepare

需要下载EEGLAB作为基础工具包，请于[EEGLAB官网](https://sccn.ucsd.edu/eeglab/)下载

本包基于MARLABR2023a实现，其它版本下可能存在版本不适应或计算差异。

## 0.1 Plugins Install：
### biosig：
在设置EEGLAB路径后，键入eeglab，左上角file中选择，manage plugins相关选项，选择biosig，安装。
* 注：

1. 1.biosig 安装较慢，主要受网络下载速度影响，请耐心等待。

2. 2.biosig 存在版本兼容问题，默认接受文件路径为 `char` 类型。
   如果报错，可删除以下代码：

   ```matlab
   filename = char(filename);
   ```

3. 安装过程中出现无法保存路径问题详情参见知乎文章：[matlab中解决路径文件pathdef.m为只读文件无法保存到matlab启动文件夹的问题](https://zhuanlan.zhihu.com/p/656555013)

### clean_rawdata（使用ASR时）：
在EEGLAB的插件管理器中安装并加载`clean_rawdata`。默认自动方法包含`"asr"`，因此需要其中的`clean_asr`、`asr_calibrate`和`asr_process`函数；单独使用`robust`和人工复核不依赖该插件。ICA方法使用EEGLAB自带的`runica`。
重采样和Butterworth滤波还需要MATLAB Signal Processing Toolbox或路径中兼容的相关函数。


# 1 数据切分
总体来说，请参见函数文件的segment_pipeline，以下分步骤讲解

## 1.1 获取markerlist
读取输入路径的全部BDF文件，并逐一读取，得到所有的marker信息，此步骤全自动，由于可能存在坏数据，可能用时较长。

## 1.2 自动筛检异常marker列
将所获取的marker列进行自动检测，默认根据Robust Z-score 离群值检测异常数量的marker列（主要用于应对由于数据损坏导致的数据问题），这一步为全自动。
这一步可以输入需要忽略的数据列，即data_ignore.xlsx，用于排除在实验中由于数据质量/被试/其它问题导致的需要排除的数据。
data_ignore.xlsx文件格式如下：
| 名称 | |  |
|:---:|:---:|:--:|
| 001  |   |   |
| 002  |   |   |

其中的001；002请输入对应的需要排除的BDF名称
如果有需要细致的marker自动筛选，如marker数大于小于某个值，可以进入core下的Marker_CheckByCount修正。

## 1.3 手动选择数据列
对有效数据进行逐一marker输入，在这一步中，会弹出弹窗（如果提示：无法对xxx数据进行.的处理方式等报错，请重启matlab，这是由于matlab缓冲导致的。）
弹窗中，上方显示所有在实验中打出的marker的时间点以及所标记的类型，请根据你们的实验要求进行数据拆分。

Marker界面同时以完整整数显示`Sample index`和`Time (ms)`，不会使用科学计数法；毫秒四舍五入且不保留小数。Start、End统一填写`Time (ms)`，不能直接把样本索引当作毫秒使用。

文件较多时可在`segment_pipeline`第5参数传入XLSX，跳过逐文件手工输入。XLSX每行表示一个区间，必需列为`file_name`、`segment_name`、`start`、`end`、`unit`。`unit`必须明确写`time_ms`、`time_s`或`sample_index`；同一文件、同一分段可以写多行。可选`enabled`列用于临时关闭某行。XLSX模式不会再按跨文件Marker数量离群值排除文件，但读取失败和忽略名单仍然生效。

`+HyperEEG/+MultiCH/example`中提供`segment_plan_example.xlsx`和`data_ignore_example.xlsx`。忽略名单只在第一个工作表填写一列不带`.bdf`扩展名的基本文件名，不要增加备注列。
点击添加片段按钮，在下方填入名称，开始时间，结束时间，其中名称可以在多个段之间重复，任意填写即可（为保证数据质量，尽量是英文和数字，理论上中文也可以）。
结束时间必须大于开始时间，结束时间可以填写end标识到数据采集完毕。

## 1.4 数据切分
会根据前一段的marker对数据进行切分，需要注意的是，这一步仅会处理有效数据，是否有效可以在前一段得到的segmentinfo中的dataflag查看，此步骤完全自动。
值得注意的是，如果有想要额外保存到BDF原始数据，请进入EEGdataSaver修正。

# 2 坏段识别与去除
总体流程请参见`Artifact_pipeline`。该流程可读取原始连续BDF或数据切分阶段产生的`_segment.mat`，先进行自动识别，再进行人工复核，最后统一排除坏段并保存。

```matlab
HyperEEG.MultiCH.pipeline.Artifact_pipeline(inputDir,outputDir)
```

其中`inputDir`可为BDF目录或`_segment.mat`目录，`outputDir`为处理结果目录。通过`autoOptions.inputType="bdf"|"segment"|"auto"`明确输入；BDF输出为`原名_artifact.mat`。数据切分和坏段处理日志统一保存在当前工作目录的`log`文件夹，名称分别采用`时间_segment.txt`和`时间_artifact.txt`。

两个Pipeline默认开启日志。如需关闭，可在最后一个参数传入`"off"`：

```matlab
HyperEEG.MultiCH.pipeline.segment_pipeline( ...
    RawInputDir,outputDir,DataIgnorePath,"off")

HyperEEG.MultiCH.pipeline.Artifact_pipeline( ...
    inputDir,outputDir,struct(),"off")
```

## 2.1 自动识别坏段
自动步骤采用滑动窗口，并综合峰峰值、突跳、高频噪声、平线和多通道协方差变化。默认阈值相对宽松，需要多个指标或多个通道共同支持才会标记普通异常，目的是为人工复核提供初筛结果，而不是完全替代人工判断。

如需调整自动识别参数，可传入第三个参数：

```matlab
autoOptions.windowDuration_s = 2;
autoOptions.windowOverlap = 0.5;
autoOptions.robustZThreshold = 6;
autoOptions.severeZThreshold = 10;

HyperEEG.MultiCH.pipeline.Artifact_pipeline( ...
    inputDir,outputDir,autoOptions)
```

参数数值越小通常越敏感，也越容易误删。修改后应先结合人工波形检查验证，不建议直接将探索性参数用于全部数据。

## 2.2 人工复核坏段
每个文件完成自动识别后会打开波形窗口和Segment Editor。`Channel`填写0到通道总数之间的整数，0表示全部通道，1开始表示指定通道；`Start`和`End`填写坏段时间。只填写`Channel > 0`表示整条指定通道均为坏数据；只填写`Channel = 0`表示整个文件全部通道无效，确认后整文件排除，不生成`_artifact.mat`，也不进入后续流程。原始`_segment.mat`不会被删除。人工函数只记录标记，不会立即修改数据；如果没有额外坏段，可以直接确认。点击取消同样会跳过当前文件，但日志状态与“整文件排除”不同。

## 2.3 统一切割与保存
自动和人工标记分别保存在：

```matlab
EEGdata.artifact.auto
EEGdata.artifact.manual
```

自动或人工标记中的`channel = 0`表示全局坏时间段，Pipeline会从`EEGdata.times`和所有通道中删除对应时间列。`channel > 0`只将指定通道对应区间设为`NaN`，不会删除其它通道的数据，也不会破坏公共时间轴。其它已有字段保持不变，便于从输出结果追溯自动与人工标记。

# 3 脑电预处理
预处理流程可读取BDF、`_segment.mat`或坏段阶段产生的`_artifact.mat`，并输出`_clean.mat`。统一UI会根据所选顺序自动指定输入类型；直接调用时可设置`options.inputType`。最小调用如下：

```matlab
HyperEEG.MultiCH.pipeline.Preprocess_pipeline(inputDir,outputDir)
```

默认依次执行线性去趋势、0.5–80 Hz带通、50 Hz Notch、`robust + ASR`自动伪迹处理、人工ICA成分选择和最终通道频域复核。重采样和重参考默认关闭。两个人工步骤默认开启，因此每个未取消、未报错的文件都会先显示ICA界面，再显示通道×频率(Hz) PSD界面。

## 3.1 常用配置
连接类指标可先采用较保守的1–45 Hz预设：

```matlab
options.resample.enabled = true;
options.resample.targetRate = 250;
options.bandpass.profile = "connectivity";
options.reference.enabled = false;
options.artifact.auto.methods = ["robust","asr"];
options.artifact.icaManual.enabled = true;
options.artifact.manual.enabled = true;

HyperEEG.MultiCH.pipeline.Preprocess_pipeline( ...
    inputDir,outputDir,options)
```

带通预设包括`broadband`、`connectivity`、`erp`、`time_frequency`和`slow`。也可直接设置自定义范围：

```matlab
options.bandpass.profile = "custom";
options.bandpass.rangeHz = [1,40];
```

若带通上限已经低于50 Hz，Notch通常影响很小，但默认仍执行并记录。采样率过低、50 Hz超过Nyquist频率时会自动跳过Notch，并在处理历史中记录原因。

## 3.2 自动与人工伪迹处理
自动步骤通过`options.artifact.auto.methods`配置，支持：

- `"robust"`：使用滑动局部中位数和MAD识别极端瞬态，只修复异常值；默认流程首先执行该方法；
- `"ica"`：调用EEGLAB `runica`，使用成分峰度与高频变化联合筛选，也可用`icaRejectComponents`人工指定成分；
- `"asr"`：调用EEGLAB clean_rawdata插件的ASR，默认`BurstCriterion=20`且保持样本数不变；
- `"none"`：不执行额外伪迹修复。

默认按`["robust","asr"]`顺序自动执行。ASR依据阈值自动校准并重建异常子空间，不需要人工逐个判断成分。随后单独计算ICA并打开人工成分界面；这不是自动ICA，不会在用户确认前删除成分。八通道或更少数据中的ICA分离证据有限，应只删除形态非常明确的眼动、心电、肌电或电极噪声成分，不确定时保留。

人工ICA界面显示每个成分的时间序列、功率谱、通道权重和辅助异常分数。最终复核提供上一个/下一个通道按钮和可点击Hz游标，可标记整条坏导、整文件无效，或记录某通道的可疑频段。若希望重新选择ICA成分，可点击“退回上一步，重新ICA”；Pipeline会放弃本轮尚未确认的频域标记，从首次人工ICA前数据重新执行ICA，再次进入最终复核。若新增整条坏导，Pipeline同样从首次ICA前数据恢复、累计屏蔽坏导并对剩余通道重新ICA，直至本轮不再新增坏导；可疑频段只记录，不触发重跑。每轮已确认结果保存在`icaManual.rounds`和`frequencyManual.rounds`。

全部文件完成后可运行`QualityIndex_pipeline`。该流程按raw、segment、artifact、clean四级结果判断记录是否一直保留到最新步骤，并在返回的`qualityTable`中给出`isValid`和`deletionReason`。质量结果只保存在`EEGdata.quality`：`badchannel`为整条排除的坏导，`channelrate`为N×2 cell（通道名、0到1的比例），总体比例为`totalEffectiveRate`。逐通道比例以完整时间轴总时长为分母，`NaN/Inf`和已删除的时间缺口均计为无效；总体比例为全部通道有效时长之和除以“总时长×通道数”。项目Excel清单可根据`qualityTable`单独维护，不由包内函数直接改写。

## 3.3 是否需要重参考
采集到的EEG一定已经相对于设备的某个硬件参考形成电位差，但后处理阶段并非必须再次重参考。没有明确的参考电极信息、只有少量通道，或最终分析不要求统一参考时，可以保持`options.reference.enabled = false`。平均参考更适合电极覆盖较均匀且通道较多的情况；指定通道参考必须建立在明确的电极布局和研究方案上，不应随意选择。当前Pipeline的重参考位于ICA之前，因此自动方法包含ICA时不得使用非线性的`median`参考，可关闭重参考或改用`average/channel`。

## 3.4 输出与追溯
处理后的采样率保存在`EEGdata.etc.samplerate.clean`，完整参数和逐步结果保存在`EEGdata.preprocessing`，输出路径保存在`EEGdata.file.cleanpath`。滤波和重采样按原时间轴的连续片段分别执行，不会跨坏段删除产生的时间跳跃滤波；波形查看器也会在时间缺口处留出真实空白，不连接断点两侧。之前以`NaN`保存的坏通道区间仍会保留。单通道数据会自动跳过默认的中位数/平均重参考，避免整条信号被减成零。

每个EEGdata还包含统一状态表`EEGdata.Process`。全部字段在首次创建时预置为0，对应操作真正完成后改为1；关闭、跳过、取消或异常均保持0。主要字段包括：

```matlab
EEGdata.Process.segment
EEGdata.Process.artifact_auto
EEGdata.Process.artifact_manual
EEGdata.Process.resample
EEGdata.Process.detrend
EEGdata.Process.bandpass
EEGdata.Process.notch
EEGdata.Process.reference
EEGdata.Process.robust
EEGdata.Process.asr
EEGdata.Process.ica
EEGdata.Process.ica_manual
EEGdata.Process.preprocess_manual
EEGdata.Process.preprocess_complete
```

算法标准缩写为`ASR`，因此字段名使用`asr`而不是`rsa`。旧MAT文件进入后续Pipeline时会自动补齐缺失状态字段，不需要重新生成原始阶段数据。

示例文件位于`+HyperEEG/+MultiCH/example/Preprocess_pipeline_example.m`。

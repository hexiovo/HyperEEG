# HyperEEG---lecture-Paradigm
notice:本项目仅适用于多人无互动学习范式，其具有高度的特异性，如需迁移，请在看懂本包的基础上做适当调整。

authority：[hexi](https://github.com/hexiovo)

email：[彭洋](mailto:py_edu_mail@163.com)

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
3. 3.安装过程中出现无法保存路径问题详情参见知乎文章：[matlab中解决路径文件pathdef.m为只读文件无法保存到matlab启动文件夹的问题](https://zhuanlan.zhihu.com/p/656555013)


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
点击添加片段按钮，在下方填入名称，开始时间，结束时间，其中名称可以在多个段之间重复，任意填写即可（为保证数据质量，尽量是英文和数字，理论上中文也可以）。
结束时间必须大于开始时间，结束时间可以填写end标识到数据采集完毕。

## 1.4 数据切分
会根据前一段的marker对数据进行切分，需要注意的是，这一步仅会处理有效数据，是否有效可以在前一段得到的segmentinfo中的dataflag查看，此步骤完全自动。
值得注意的是，如果有想要额外保存到BDF原始数据，请进入EEGdataSaver修正。
# Function Document
**本说明将按章节对各部分涉及的函数进行说明。**

## Content
- [Pipeline](#Pipeline)
  - [segment_pipeline](#segment_pipeline)

- [Main](#Main)
  - [MarkerExtract](#MarkerExtract)
  - [MarkerList](#MarkerList)
  - [MarkerSegmentEditor](#MarkerSegmentEditor)
  - [MarkerCheck_Auto](#MarkerCheck_Auto)
  - [MarkerCheck_Manual](#MarkerCheck_Manual)
  - [segment_Marker](#segment_Marker)
- [core](#Core)
  - [BDFreader](#BDFreader)
  - [Marker_CheckByCount](#Marker_CheckByCount)
  - [EEGdataSaver](#EEGdataSaver)
- [misc](#Misc)
  - [getFiles](#getFiles)
  - [Segmentmerge](#Segmentmerge)
  - [InitLogFile](#InitLogFile)




## Pipeline
**本部分为集成函数，调用后续函数进行处理**
### segment_pipeline
```matlab
segment_pipeline(RawInputDir,outputDir,DataIgnorePath)
```
完成从数据输入到根据marker分割的全过程。其中：
```matlab
RawInputDir:原始BDF文件存储地址
outputDir:目标输入地址，不能与上述等同
DataIgnorePath:需要忽视的数据名，格式为列数据，首行为表头，任意填写，如：姓名。下方为各自数据的对应名称。
```
data_ignore.xlsx文件格式如下：
| 名称 | |  |
|:---:|:---:|:--:|
| 001  |   |   |
| 002  |   |   |



## Main
**本部分为数据处理的封装函数，用于调用算法以及各种子集函数，实现单一功能**
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
传入格式为带有type和latency的mark列，弹出提示框，键入对应的分段以及名称，返回键入列以及是否取消，取消赋值emptybool = 1

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

## Core
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
logFile = InitLogFile(path, name)
```
生成初始log日志文件，默认为log下命名为HyperEEG，可自定义
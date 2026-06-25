# Function Document
**本说明将按章节对各部分涉及的函数进行说明。**

## Content
- [Pipeline](#Pipeline)
  - [1](#1)

- [Main](#Main)
  - [1](#12)

- [core](#Core)
  - [BDFreader](#BDFreader)

- [misc](#Misc)
  - [getFiles](#getFiles)

## Pipeline
**本部分为集成函数，调用后续函数进行处理**
### 1



## Main
**本部分为数据处理的封装函数，用于调用算法以及各种子集函数，实现单一功能**
### 12



## Core
**本部分为底层计算函数，实现单一功能，若需要进行修改，这部分是核心修改内容**
### BDFreader
```matlab
EEG = BDFreader(inputDir);
```
用于读取制定输入路径的BDF文件并返回。
接受string和char两种模式的输入，最终转换为char格式，这是为了适应biosig的读取规则（只接受char路径），如有变动请自行修改。




## Misc
**本部分为底层处理函数，实现单一功能，主要是负责进行包装，文件读取等。**
### getFiles
```matlab
filePaths = getFiles(rootPath, ext)
```
递归获取指定后缀文件
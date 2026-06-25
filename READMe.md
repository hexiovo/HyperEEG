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

1. biosig 安装较慢，主要受网络下载速度影响，请耐心等待。

2. biosig 存在版本兼容问题，默认接受文件路径为 `char` 类型。
   如果报错，可删除以下代码：

   ```matlab
   filename = char(filename);
3. 安装过程中出现无法保存路径问题详情参见知乎文章：[matlab中解决路径文件pathdef.m为只读文件无法保存到matlab启动文件夹的问题](https://zhuanlan.zhihu.com/p/656555013)


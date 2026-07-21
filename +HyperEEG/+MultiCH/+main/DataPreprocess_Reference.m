function [EEGdata, info] = DataPreprocess_Reference(EEGdata, options)
%DATAPREPROCESS_REFERENCE 重参考业务封装。
%   本步骤可选；没有明确参考方案或通道很少时应保持关闭。

    [EEGdata.data, info] = ...
        HyperEEG.MultiCH.core.PreprocessReference( ...
        EEGdata.data, options.method, options.channels);

end

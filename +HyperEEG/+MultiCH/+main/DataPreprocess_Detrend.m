function [EEGdata, info] = DataPreprocess_Detrend(EEGdata, options)
%DATAPREPROCESS_DETREND 去趋势业务封装。
%   仅替换EEGdata.data，其它元数据和毫秒时间轴保持不变。

    [EEGdata.data, info] = HyperEEG.MultiCH.core.PreprocessDetrend( ...
        EEGdata.data, EEGdata.times, options.method);

end

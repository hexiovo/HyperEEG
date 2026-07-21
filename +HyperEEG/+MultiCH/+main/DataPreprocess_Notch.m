function [EEGdata, info] = DataPreprocess_Notch(EEGdata, options)
%DATAPREPROCESS_NOTCH 工频滤波业务封装。
%   自动读取当前采样率，并传递中心频率、总带宽和滤波阶数。

    sampleRate = HyperEEG.MultiCH.core.PreprocessSampleRate(EEGdata);
    [EEGdata.data, info] = HyperEEG.MultiCH.core.PreprocessNotch( ...
        EEGdata.data, EEGdata.times, sampleRate, ...
        options.lineFrequencyHz, options.bandwidthHz, options.order);

end

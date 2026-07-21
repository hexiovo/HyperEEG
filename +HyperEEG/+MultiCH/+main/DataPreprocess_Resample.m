function [EEGdata, info] = DataPreprocess_Resample(EEGdata, options)
%DATAPREPROCESS_RESAMPLE 重采样业务封装，并同步更新时间轴与采样率。
%   options.targetRate单位为Hz；原始采样率仍保存在samplerate.raw。

    sourceRate = HyperEEG.MultiCH.core.PreprocessSampleRate(EEGdata);
    [EEGdata.data, EEGdata.times, info] = ...
        HyperEEG.MultiCH.core.PreprocessResample( ...
        EEGdata.data, EEGdata.times, sourceRate, options.targetRate);

    % 只更新clean采样率，不覆盖可追溯的原始采样率。
    if ~isfield(EEGdata, "etc")
        EEGdata.etc = struct();
    end

    if ~isfield(EEGdata.etc, "samplerate") || ...
            ~isstruct(EEGdata.etc.samplerate)
        EEGdata.etc.samplerate = struct('raw', sourceRate);
    end

    EEGdata.etc.samplerate.clean = info.targetRate;

end

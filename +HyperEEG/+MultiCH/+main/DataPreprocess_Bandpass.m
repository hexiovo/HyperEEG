function [EEGdata, info] = DataPreprocess_Bandpass(EEGdata, options)
%DATAPREPROCESS_BANDPASS 解析分析预设并调用核心带通滤波。
%   options.rangeHz非空时优先于profile，info会记录预设及实际范围。

    sampleRate = HyperEEG.MultiCH.core.PreprocessSampleRate(EEGdata);
    frequencyRange = resolveFrequencyRange(options);
    [EEGdata.data, info] = ...
        HyperEEG.MultiCH.core.PreprocessBandpass( ...
        EEGdata.data, EEGdata.times, sampleRate, ...
        frequencyRange, options.order);
    info.profile = string(options.profile);

end

function frequencyRange = resolveFrequencyRange(options)
%RESOLVEFREQUENCYRANGE 将研究用途预设转换为[低截止,高截止] Hz。

    if ~isempty(options.rangeHz)
        frequencyRange = options.rangeHz;
        return;
    end

    % 预设只提供可重复的起点，正式研究仍需提前固定频率范围。
    switch lower(string(options.profile))
        case "broadband"
            frequencyRange = [0.5, 80];
        case "connectivity"
            frequencyRange = [1, 45];
        case "erp"
            frequencyRange = [0.1, 30];
        case "time_frequency"
            frequencyRange = [1, 80];
        case "slow"
            frequencyRange = [0.1, 15];
        case "custom"
            error("bandpass.profile为custom时必须设置rangeHz。");
        otherwise
            error("未知带通预设：%s", string(options.profile));
    end

end

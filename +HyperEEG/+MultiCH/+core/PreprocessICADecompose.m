function model = PreprocessICADecompose(data, sampleRate)
%PREPROCESSICADECOMPOSE 计算人工或自动复用的extended Infomax ICA模型。
%   输入为通道×采样点。NaN仅在估计期间临时插值；model保留原始
%   缺失掩码，供重建函数恢复。该函数只分解，不判定或删除成分。

    if exist('runica', 'file') ~= 2
        error("未找到EEGLAB runica，请先添加EEGLAB路径。");
    end

    validateattributes(sampleRate, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});

    [filledData, missingMask] = ...
        HyperEEG.MultiCH.core.PreprocessFillMissing(data);
    usableChannel = ~all(missingMask, 2);
    usableData = filledData(usableChannel, :);

    if size(usableData, 1) < 2
        error("ICA至少需要两个有效通道。");
    end

    channelCenter = mean(usableData, 2);
    centeredData = usableData - channelCenter;
    dataRank = rank(centeredData);

    if dataRank < 2
        error("数据秩小于2，无法执行ICA。");
    end

    runicaOptions = {'extended', 1, 'verbose', 'off', ...
        'interrupt', 'off'};

    if dataRank < size(centeredData, 1)
        runicaOptions = [runicaOptions, {'pca', dataRank}];
    end

    [weights, sphere] = runica(centeredData, runicaOptions{:});
    unmixingMatrix = weights * sphere;
    activation = unmixingMatrix * centeredData;
    mixingMatrix = pinv(unmixingMatrix);
    activationScale = std(activation, 0, 2);
    activationScale(activationScale <= eps) = 1;
    normalizedActivation = (activation - mean(activation, 2)) ./ ...
        activationScale;
    excessKurtosis = mean(normalizedActivation .^ 4, 2) - 3;
    differenceRatio = sqrt(mean(diff(activation, 1, 2) .^ 2, 2)) ./ ...
        activationScale;

    model.activation = activation;
    model.mixingMatrix = mixingMatrix;
    model.unmixingMatrix = unmixingMatrix;
    model.channelCenter = channelCenter;
    model.usableChannel = usableChannel;
    model.missingMask = missingMask;
    model.originalData = double(data);
    model.sampleRate = sampleRate;
    model.dataRank = dataRank;
    model.componentCount = size(activation, 1);
    model.excessKurtosis = excessKurtosis(:)';
    model.kurtosisZ = robustZ(excessKurtosis(:))';
    model.highFrequencyZ = robustZ( ...
        log(max(differenceRatio(:), eps)))';

end

function zScore = robustZ(values)
%ROBUSTZ 使用中位数和MAD生成仅供人工参考的稳健异常分数。

    centerValue = median(values);
    scaleValue = median(abs(values - centerValue));
    scaleValue = max(scaleValue, max(abs(centerValue), 1) * 1e-12);
    zScore = 0.67448975 * (values - centerValue) / scaleValue;

end

function [frequencyHz, powerDb] = PreprocessChannelSpectrum( ...
        data, timeValues, sampleRate)
%PREPROCESSCHANNELSPECTRUM 计算最终人工复核使用的通道×频率PSD。
%   输出powerDb为通道×频率，frequencyHz单位Hz。时间不连续数据按
%   连续块分别估计并按样本数加权，不跨已删除坏段计算频谱。

    if size(data, 2) ~= numel(timeValues)
        error("data采样点数必须与timeValues长度一致。");
    end

    validateattributes(sampleRate, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    data = double(data);
    blocks = HyperEEG.MultiCH.core.PreprocessContinuousBlocks(timeValues);
    targetWindow = max(32, round(2 * sampleRate));
    fftLength = max(256, 2 ^ nextpow2(targetWindow));
    frequencyHz = (0:floor(fftLength / 2))' * ...
        sampleRate / fftLength;
    accumulatedPower = zeros(size(data, 1), numel(frequencyHz));
    accumulatedWeight = zeros(size(data, 1), 1);
    originalMissing = isnan(data) | isinf(data);

    for iblock = 1:size(blocks, 1)
        blockIndex = blocks(iblock, 1):blocks(iblock, 2);

        if numel(blockIndex) < 4
            continue;
        end

        [filledBlock, ~] = ...
            HyperEEG.MultiCH.core.PreprocessFillMissing( ...
            data(:, blockIndex));
        windowLength = min(targetWindow, numel(blockIndex));
        overlapLength = floor(windowLength / 2);

        for ichannel = 1:size(data, 1)
            if all(originalMissing(ichannel, blockIndex))
                continue;
            end

            if exist('pwelch', 'file') == 2
                currentPower = pwelch(filledBlock(ichannel, :), ...
                    windowLength, overlapLength, fftLength, sampleRate);
            else
                currentFFT = fft(filledBlock(ichannel, :), fftLength);
                currentPower = abs(currentFFT(1:numel(frequencyHz))) .^ 2 / ...
                    (sampleRate * numel(blockIndex));
            end

            blockWeight = numel(blockIndex);
            accumulatedPower(ichannel, :) = ...
                accumulatedPower(ichannel, :) + ...
                currentPower(:)' * blockWeight;
            accumulatedWeight(ichannel) = ...
                accumulatedWeight(ichannel) + blockWeight;
        end
    end

    validChannel = accumulatedWeight > 0;
    powerValue = nan(size(accumulatedPower));
    powerValue(validChannel, :) = accumulatedPower(validChannel, :) ./ ...
        accumulatedWeight(validChannel);
    positivePower = powerValue(isfinite(powerValue) & powerValue > 0);

    if isempty(positivePower)
        powerFloor = eps;
    else
        powerFloor = max(max(positivePower) * 1e-12, eps);
    end

    powerDb = 10 * log10(max(powerValue, powerFloor));
    powerDb(~isfinite(powerValue)) = NaN;

end

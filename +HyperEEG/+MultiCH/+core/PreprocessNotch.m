function [outputData, info] = PreprocessNotch( ...
        data, timeValues, sampleRate, lineFrequencyHz, bandwidthHz, order)
%PREPROCESSNOTCH 执行零相位Butterworth工频带阻滤波。
%   lineFrequencyHz通常为50或60 Hz，bandwidthHz为阻带总宽度。
%   工频阻带超出Nyquist范围时安全跳过，并在info.reason中说明。

    validateattributes(sampleRate, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(lineFrequencyHz, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(bandwidthHz, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(order, {'numeric'}, ...
        {'scalar', 'integer', 'positive'});

    nyquistRate = sampleRate / 2;
    stopRange = lineFrequencyHz + [-1, 1] * bandwidthHz / 2;
    outputData = double(data);

    info.method = "zero_phase_butterworth_bandstop";
    info.lineFrequencyHz = lineFrequencyHz;
    info.bandwidthHz = bandwidthHz;
    info.order = order;
    info.applied = false;
    info.skippedBlockCount = 0;

    % 低采样率下不能设计包含工频中心的合法数字滤波器。
    if stopRange(1) <= 0 || stopRange(2) >= nyquistRate
        info.reason = "line_frequency_outside_nyquist";
        return;
    end

    [b, a] = butter(order, stopRange / nyquistRate, 'stop');
    blocks = HyperEEG.MultiCH.core.PreprocessContinuousBlocks(timeValues);
    minimumLength = 3 * (max(numel(a), numel(b)) - 1) + 1;

    for iblock = 1:size(blocks, 1)
        blockIndex = blocks(iblock, 1):blocks(iblock, 2);

        % 过短片段不满足filtfilt长度要求，保留原数据而不是报废文件。
        if numel(blockIndex) < minimumLength
            info.skippedBlockCount = info.skippedBlockCount + 1;
            continue;
        end

        [filledBlock, missingBlock] = ...
            HyperEEG.MultiCH.core.PreprocessFillMissing( ...
            outputData(:, blockIndex));
        processedBlock = filtfilt(b, a, filledBlock')';
        processedBlock(missingBlock) = NaN;
        outputData(:, blockIndex) = processedBlock;
    end

    info.applied = true;
    info.reason = "";

end

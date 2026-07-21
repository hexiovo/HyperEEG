function [outputData, info] = ...
        PreprocessBandpass(data, timeValues, sampleRate, rangeHz, order)
%PREPROCESSBANDPASS 执行零相位Butterworth带通滤波。
%   rangeHz=[低截止,高截止]，单位Hz；order为Butterworth原型阶数。
%   当高截止超过Nyquist频率时会收窄至Nyquist的95%并记录实际范围。

    validateattributes(sampleRate, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(order, {'numeric'}, ...
        {'scalar', 'integer', 'positive'});
    validateattributes(rangeHz, {'numeric'}, ...
        {'vector', 'numel', 2, 'real', 'finite', 'positive'});

    nyquistRate = sampleRate / 2;
    actualRange = sort(double(rangeHz(:)'));
    actualRange(2) = min(actualRange(2), nyquistRate * 0.95);

    if actualRange(1) >= actualRange(2)
        error("带通范围与当前采样率不兼容。");
    end

    [b, a] = butter(order, actualRange / nyquistRate, 'bandpass');
    [outputData, skippedBlocks] = applyFilterByBlock( ...
        data, timeValues, b, a);

    info.method = "zero_phase_butterworth";
    info.requestedRangeHz = double(rangeHz(:)');
    info.actualRangeHz = actualRange;
    info.order = order;
    info.skippedBlockCount = skippedBlocks;

end

function [outputData, skippedBlocks] = applyFilterByBlock( ...
        data, timeValues, b, a)
%APPLYFILTERBYBLOCK 对每个足够长的连续片段独立执行filtfilt。
%   过短片段保持原值，并通过skippedBlocks返回数量。

    outputData = double(data);
    blocks = HyperEEG.MultiCH.core.PreprocessContinuousBlocks(timeValues);
    minimumLength = 3 * (max(numel(a), numel(b)) - 1) + 1;
    skippedBlocks = 0;

    for iblock = 1:size(blocks, 1)
        blockIndex = blocks(iblock, 1):blocks(iblock, 2);

        % filtfilt需要足够样本建立首尾初始状态，短片段不能强行滤波。
        if numel(blockIndex) < minimumLength
            skippedBlocks = skippedBlocks + 1;
            continue;
        end

        [filledBlock, missingBlock] = ...
            HyperEEG.MultiCH.core.PreprocessFillMissing( ...
            outputData(:, blockIndex));
        processedBlock = filtfilt(b, a, filledBlock')';
        processedBlock(missingBlock) = NaN;
        outputData(:, blockIndex) = processedBlock;
    end

end

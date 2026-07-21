function [outputData, outputTimes, info] = ...
        PreprocessResample(data, timeValues, sourceRate, targetRate)
%PREPROCESSRESAMPLE 分连续片段执行抗混叠多相FIR重采样。
%   data为通道×采样点，timeValues沿用输入时间单位（项目中为ms）。
%   输出同时更新数据和时间轴，并保留原有NaN坏导区域。

    validateattributes(sourceRate, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(targetRate, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});

    blocks = HyperEEG.MultiCH.core.PreprocessContinuousBlocks(timeValues);
    rateRatio = targetRate / sourceRate;
    [numerator, denominator] = rat(rateRatio, 1e-12);
    outputData = zeros(size(data, 1), 0);
    outputTimes = zeros(1, 0);
    missingOutput = false(size(data, 1), 0);

    % 各连续片段单独处理，避免跨时间跳跃产生虚假滤波过渡。
    for iblock = 1:size(blocks, 1)
        blockIndex = blocks(iblock, 1):blocks(iblock, 2);
        [filledBlock, missingBlock] = ...
            HyperEEG.MultiCH.core.PreprocessFillMissing( ...
            data(:, blockIndex));
        resampledBlock = resample( ...
            filledBlock', numerator, denominator)';
        newCount = size(resampledBlock, 2);

        if newCount == 1
            newTimes = timeValues(blockIndex(1));
        else
            newTimes = linspace(timeValues(blockIndex(1)), ...
                timeValues(blockIndex(end)), newCount);
        end

        originalPosition = linspace(0, 1, numel(blockIndex));
        newPosition = linspace(0, 1, newCount);
        resampledMissing = false(size(missingBlock, 1), newCount);

        % 最近邻重采样掩码，确保坏导范围不会被插值结果覆盖。
        for ichannel = 1:size(missingBlock, 1)
            resampledMissing(ichannel, :) = interp1( ...
                originalPosition, double(missingBlock(ichannel, :)), ...
                newPosition, 'nearest', 'extrap') > 0.5;
        end

        outputData = [outputData, resampledBlock]; %#ok<AGROW>
        outputTimes = [outputTimes, newTimes]; %#ok<AGROW>
        missingOutput = [missingOutput, resampledMissing]; %#ok<AGROW>
    end

    outputData(missingOutput) = NaN;
    info.method = "polyphase_fir";
    info.sourceRate = sourceRate;
    info.targetRate = targetRate;
    info.sourceSamples = size(data, 2);
    info.outputSamples = size(outputData, 2);
    info.blockCount = size(blocks, 1);

end

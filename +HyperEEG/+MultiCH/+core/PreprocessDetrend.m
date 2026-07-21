function [outputData, info] = ...
        PreprocessDetrend(data, timeValues, method)
%PREPROCESSDETREND 分连续片段移除趋势，并保留原有NaN位置。
%   method="linear"移除线性趋势；"constant"只移除每通道均值。

    method = lower(string(method));

    if ~any(strcmp(method, ["linear", "constant"]))
        error("去趋势method必须为linear或constant。");
    end

    outputData = double(data);
    blocks = HyperEEG.MultiCH.core.PreprocessContinuousBlocks(timeValues);

    % 不跨坏段断点拟合趋势，否则断点两侧会相互影响。
    for iblock = 1:size(blocks, 1)
        blockIndex = blocks(iblock, 1):blocks(iblock, 2);
        [filledBlock, missingBlock] = ...
            HyperEEG.MultiCH.core.PreprocessFillMissing( ...
            outputData(:, blockIndex));

        if method == "linear"
            processedBlock = detrend(filledBlock')';
        else
            processedBlock = filledBlock - mean(filledBlock, 2);
        end

        processedBlock(missingBlock) = NaN;
        outputData(:, blockIndex) = processedBlock;
    end

    info.method = method;
    info.blockCount = size(blocks, 1);

end

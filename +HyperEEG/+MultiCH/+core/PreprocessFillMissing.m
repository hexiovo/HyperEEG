function [filledData, missingMask] = PreprocessFillMissing(data)
%PREPROCESSFILLMISSING 临时填补非有限值，供连续信号算法计算。
%   missingMask保存原始NaN/Inf位置。调用者必须在计算结束后根据该
%   掩码恢复NaN；本函数不表示坏导已经被永久修复。

    filledData = double(data);
    missingMask = ~isfinite(filledData);
    sampleIndex = 1:size(filledData, 2);

    % 每个通道独立插值，防止其它通道的幅值进入当前通道。
    for ichannel = 1:size(filledData, 1)
        validIndex = find(~missingMask(ichannel, :));

        if isempty(validIndex)
            filledData(ichannel, :) = 0;
        elseif numel(validIndex) == 1
            filledData(ichannel, :) = filledData(ichannel, validIndex);
        else
            filledData(ichannel, :) = interp1( ...
                validIndex, filledData(ichannel, validIndex), ...
                sampleIndex, 'linear', 'extrap');
        end
    end

end

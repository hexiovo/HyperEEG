function [outputData, info] = PreprocessICAReconstruct( ...
        model, rejectComponents)
%PREPROCESSICARECONSTRUCT 将选定ICA成分置零后重建通道数据。
%   rejectComponents为空时原样返回，不引入无意义的数值重建误差。

    rejectComponents = unique(rejectComponents(:)');

    if ~isempty(rejectComponents)
        validateattributes(rejectComponents, {'numeric'}, ...
            {'vector', 'integer', 'positive', ...
            '<=', model.componentCount});
    end

    outputData = model.originalData;

    if ~isempty(rejectComponents)
        cleanedActivation = model.activation;
        cleanedActivation(rejectComponents, :) = 0;
        reconstructedData = model.mixingMatrix * cleanedActivation + ...
            model.channelCenter;
        outputData(model.usableChannel, :) = reconstructedData;
        outputData(model.missingMask) = NaN;
    end

    info.method = "extended_runica_manual";
    info.dataRank = model.dataRank;
    info.componentCount = model.componentCount;
    info.rejectedComponents = rejectComponents;
    info.kurtosisZ = model.kurtosisZ;
    info.highFrequencyZ = model.highFrequencyZ;

end

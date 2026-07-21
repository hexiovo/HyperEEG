function [EEGdata, info, cancelbool] = ...
        DataPreprocess_ArtifactICAManual( ...
        EEGdata, currentfilename, options)
%DATAPREPROCESS_ARTIFACTICAMANUAL 分解ICA、人工选择并重建数据。
%   ICA计算位于core层；本函数只编排人工界面。取消时不修改EEGdata。

    sampleRate = HyperEEG.MultiCH.core.PreprocessSampleRate(EEGdata);
    model = HyperEEG.MultiCH.core.PreprocessICADecompose( ...
        EEGdata.data, sampleRate);
    [rejectComponents, cancelbool] = ...
        HyperEEG.MultiCH.main.ICAComponentEditor( ...
        model, EEGdata.times, currentfilename);

    if cancelbool == 1
        info.method = "manual_ica_cancelled";
        return;
    end

    [EEGdata.data, info] = ...
        HyperEEG.MultiCH.core.PreprocessICAReconstruct( ...
        model, rejectComponents);
    info.reviewed = true;
    info.parameters = options;

    if ~isfield(EEGdata, "artifact")
        EEGdata.artifact = struct();
    end

    roundRecord.rejectedComponents = rejectComponents;
    roundRecord.componentCount = model.componentCount;
    roundRecord.dataRank = model.dataRank;

    if isfield(EEGdata.artifact, "icaManual") && ...
            isfield(EEGdata.artifact.icaManual, "rounds")
        EEGdata.artifact.icaManual.rounds(end + 1) = roundRecord;
    else
        EEGdata.artifact.icaManual.rounds = roundRecord;
    end

    % 即使没有删除成分也记录“已人工检查”，区别于跳过该步骤。
    EEGdata.artifact.icaManual.reviewed = true;
    EEGdata.artifact.icaManual.rejectedComponents = ...
        rejectComponents;
    EEGdata.artifact.icaManual.componentCount = model.componentCount;
    EEGdata.artifact.icaManual.dataRank = model.dataRank;
    EEGdata.artifact.icaManual.sourceFile = string(currentfilename);
    EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
        EEGdata, ["ica", "ica_manual"], 1);

end

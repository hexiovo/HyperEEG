function [EEGdata, info, cancelbool] = ...
        DataPreprocess_ArtifactICAManual( ...
        EEGdata, currentfilename, options)
%DATAPREPROCESS_ARTIFACTICAMANUAL 分解ICA、人工选择并重建数据。
%   ICA计算位于core层；本函数只编排人工界面。取消时不修改EEGdata。

    sampleRate = HyperEEG.MultiCH.core.PreprocessSampleRate(EEGdata);
    fprintf("正在估计ICA模型，完成后将自动弹出成分复核窗口。\n");
    progressFigure = createICAProgress(currentfilename);
    progressCleanup = onCleanup( ...
        @() closeICAProgress(progressFigure)); %#ok<NASGU>
    HyperEEG.MultiCH.misc.WorkflowCancel("throw");
    model = HyperEEG.MultiCH.core.PreprocessICADecompose( ...
        EEGdata.data, sampleRate, options.maxTrainingSamples);
    HyperEEG.MultiCH.misc.WorkflowCancel("throw");
    closeICAProgress(progressFigure);
    HyperEEG.MultiCH.misc.WorkflowCancel("throw");
    fprintf("ICA模型估计完成，正在打开成分复核窗口。\n");
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
    roundRecord.trainingSampleCount = model.trainingSampleCount;
    roundRecord.totalSampleCount = model.totalSampleCount;

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


function progressFigure = createICAProgress(currentfilename)
%CREATEICAPROGRESS 在同步runica计算期间提供明确的等待反馈。

    progressFigure = [];

    try
        progressFigure = waitbar(0.5, ...
            ['正在估计ICA模型，请等待。完成后会自动打开成分复核窗口。', ...
            newline, char(string(currentfilename))], ...
            'Name', 'HyperEEG：ICA计算中', ...
            'Tag', 'HyperEEGICAProgress', ...
            'CreateCancelBtn', '');
        drawnow;
    catch
        % 图形环境不可用时仍继续计算，详细状态已写入日志。
        progressFigure = [];
    end

end


function closeICAProgress(progressFigure)
%CLOSEICAPROGRESS 安全关闭ICA等待窗口。

    if ~isempty(progressFigure) && isgraphics(progressFigure)
        delete(progressFigure);
        drawnow;
    end

end

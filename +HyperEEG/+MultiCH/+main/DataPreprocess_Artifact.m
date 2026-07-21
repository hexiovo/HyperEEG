function [EEGdata, info, cancelbool] = ...
        DataPreprocess_Artifact(EEGdata, currentfilename, options)
%DATAPREPROCESS_ARTIFACT 兼容旧版单method伪迹接口。
%   新代码应分别使用DataPreprocess_ArtifactAuto和
%   DataPreprocess_ArtifactManual；保留本函数以避免旧脚本失效。

    cancelbool = 0;
    method = lower(string(options.method));

    % 旧接口使用method="manual"区分交互路径，其余方法进入core层。
    if method == "manual"
        [manualSegment, cancelbool, excludeFileBool] = ...
            HyperEEG.MultiCH.main.DataArtifact_Manual( ...
            EEGdata, currentfilename);

        if cancelbool == 1
            info.method = "manual_cancelled";
            return;
        end

        if excludeFileBool == 1
            info.method = "manual_exclude_file";
            info.excludeFileBool = true;
            return;
        end

        if ~isfield(EEGdata, "artifact")
            EEGdata.artifact = struct();
        end

        if isfield(EEGdata.artifact, "manual")
            EEGdata.artifact.manual = [ ...
                EEGdata.artifact.manual(:)', manualSegment(:)'];
        else
            EEGdata.artifact.manual = manualSegment;
        end
        [EEGdata, removedSampleCount, maskedValueCount] = ...
            HyperEEG.MultiCH.main.DataArtifact_segment( ...
            EEGdata, manualSegment);
        info.method = "manual";
        info.removedSampleCount = removedSampleCount;
        info.maskedValueCount = maskedValueCount;
        EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
            EEGdata, "preprocess_manual", 1);
        return;
    end

    sampleRate = HyperEEG.MultiCH.core.PreprocessSampleRate(EEGdata);
    channelInfo = [];

    if isfield(EEGdata, "etc") && ...
            isfield(EEGdata.etc, "channel") && ...
            isfield(EEGdata.etc.channel, "info")
        channelInfo = EEGdata.etc.channel.info;
    end

    [EEGdata.data, info] = ...
        HyperEEG.MultiCH.core.PreprocessArtifact( ...
        EEGdata.data, EEGdata.times, sampleRate, ...
        method, options, channelInfo);

    if ismember(method, ["robust", "asr"])
        EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
            EEGdata, method, 1);
    elseif method == "ica"
        EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
            EEGdata, ["ica", "ica_auto"], 1);
    end

end

function [EEGdata, info, cancelbool, excludeFileBool, rerunICABool] = ...
        DataPreprocess_ArtifactManual( ...
        EEGdata, currentfilename, allowRerunICA)
%DATAPREPROCESS_ARTIFACTMANUAL 执行最终通道频域人工质量复核。
%   界面输出通道×频率Hz的PSD；可标记整条坏导或排除整文件。
%   可请求返回上一步重新执行ICA；时间坏段仍由前序Artifact_pipeline
%   的时域界面负责。

    if nargin < 3
        allowRerunICA = true;
    end

    [reviewResult, cancelbool, excludeFileBool, rerunICABool] = ...
        HyperEEG.MultiCH.main.FrequencyReviewEditor( ...
        EEGdata, currentfilename, allowRerunICA);

    if rerunICABool == 1
        info.method = "manual_request_rerun_ica";
        return;
    end

    if cancelbool == 1
        info.method = "manual_cancelled";
        return;
    end

    if excludeFileBool == 1
        info.method = "manual_frequency_exclude_file";
        return;
    end

    if ~isfield(EEGdata, "artifact")
        EEGdata.artifact = struct();
    end

    frequencyRound.channel = reviewResult.channel;
    frequencyRound.frequencyHz = reviewResult.frequencyHz;
    frequencyRound.powerDb = reviewResult.powerDb;
    frequencyRound.badChannels = reviewResult.badChannels;
    frequencyRound.flaggedBands = reviewResult.flaggedBands;

    if isfield(EEGdata.artifact, "frequencyManual") && ...
            isfield(EEGdata.artifact.frequencyManual, "rounds")
        EEGdata.artifact.frequencyManual.rounds(end + 1) = ...
            frequencyRound;
    else
        EEGdata.artifact.frequencyManual.rounds = frequencyRound;
    end

    EEGdata.artifact.frequencyManual.reviewed = true;
    EEGdata.artifact.frequencyManual.channel = reviewResult.channel;
    EEGdata.artifact.frequencyManual.frequencyHz = ...
        reviewResult.frequencyHz;
    EEGdata.artifact.frequencyManual.powerDb = reviewResult.powerDb;
    EEGdata.artifact.frequencyManual.badChannels = ...
        reviewResult.badChannels;
    EEGdata.artifact.frequencyManual.flaggedBands = ...
        reviewResult.flaggedBands;

    manualSegment = buildWholeChannelSegments( ...
        reviewResult.badChannels, EEGdata.times);

    % 将频域复核确认的整条坏导追加到既有人工标记中。
    if ~isempty(manualSegment)
        if isfield(EEGdata.artifact, "manual")
            EEGdata.artifact.manual = [ ...
                EEGdata.artifact.manual(:)', manualSegment(:)'];
        else
            EEGdata.artifact.manual = manualSegment;
        end
    end

    [EEGdata, removedSampleCount, maskedValueCount] = ...
        HyperEEG.MultiCH.main.DataArtifact_segment( ...
        EEGdata, manualSegment);
    info.method = "manual_channel_frequency_review";
    info.badChannels = reviewResult.badChannels;
    info.frequencyBinCount = numel(reviewResult.frequencyHz);
    info.flaggedBandCount = numel(reviewResult.flaggedBands);
    info.removedSampleCount = removedSampleCount;
    info.maskedValueCount = maskedValueCount;
    EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
        EEGdata, "preprocess_manual", 1);

end

function manualSegment = buildWholeChannelSegments( ...
        badChannels, timeValues)
%BUILDWHOLECHANNELSEGMENTS 将坏导列表转换为覆盖全数据的标记。

    manualSegment = struct('channel', {}, 'intervals', {});

    if isempty(badChannels)
        return;
    end

    timeRange = [min(timeValues), max(timeValues)];

    for ichannel = 1:numel(badChannels)
        manualSegment(ichannel).channel = badChannels(ichannel);
        manualSegment(ichannel).intervals = timeRange;
    end

end

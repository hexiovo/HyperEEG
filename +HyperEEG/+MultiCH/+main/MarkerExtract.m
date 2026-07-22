function [marker, metadata, readSuccess] = MarkerExtract(filename)
%MARKEREXTRACT 从一个BDF文件读取EEGLAB event列表。
%   marker.time_ms明确保存相对EEG时间轴的毫秒位置，避免把EEGLAB的
%   latency样本索引直接与EEG.times毫秒值混用。旧的一输出调用保持兼容。

    metadata = struct('sampleRate', NaN, 'firstTime_ms', 0);
    readSuccess = false;
    
    try
        evalc('EEG = HyperEEG.MultiCH.core.BDFreader(filename);');
        readSuccess = true;
    catch ME
        warning('MarkerExtract:BDFReadFail', ...
            'BDF reading failed: %s', ME.message);
        EEG = struct();
    end

    if ~isfield(EEG, 'event') || isempty(EEG.event)
        warning('MarkerExtract:MissingEvent', 'EEG.event missing. Creating empty event struct.');

        EEG.event = struct( ...
            'type', {}, ...
            'latency', {}, ...
            'duration', {}, ...
            'channel', {}, ...
            'time_ms', {} ...
        );
    end

    if isfield(EEG, 'srate') && isnumeric(EEG.srate) && ...
            isscalar(EEG.srate) && EEG.srate > 0
        metadata.sampleRate = double(EEG.srate);
    end

    if isfield(EEG, 'times') && ~isempty(EEG.times)
        metadata.firstTime_ms = double(EEG.times(1));
    elseif isfield(EEG, 'xmin') && isnumeric(EEG.xmin) && ...
            isscalar(EEG.xmin)
        metadata.firstTime_ms = double(EEG.xmin) * 1000;
    end

    % EEGLAB latency以第1个采样点为1；EEG.times以毫秒表示。
    if ~isempty(EEG.event) && isfinite(metadata.sampleRate)
        for ievent = 1:numel(EEG.event)
            latency = double(EEG.event(ievent).latency);
            EEG.event(ievent).time_ms = metadata.firstTime_ms + ...
                (latency - 1) / metadata.sampleRate * 1000;
        end
    end

    marker = EEG.event;
end

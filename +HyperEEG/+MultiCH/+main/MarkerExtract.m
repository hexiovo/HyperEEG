function marker = MarkerExtract(filename)
%MARKEREXTRACT 从一个BDF文件读取EEGLAB event列表。
%   读取失败或缺少event时返回空事件结构，并发出可记录的warning。
    
    try
        evalc('EEG = HyperEEG.MultiCH.core.BDFreader(filename);');
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
            'channel', {} ...
        );
    end

    marker = EEG.event;
end

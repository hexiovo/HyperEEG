function marker = MarkerExtract(filename)
    
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
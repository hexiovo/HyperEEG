function EEGdata = EEGdataFromBDF(filepath)
%EEGDATAFROMBDF 将一份BDF转换为连续EEGdata，不执行分段或信号处理。
%   原始BDF保持只读；事件同时保留EEGLAB latency样本索引和time_ms。

    if ~isfile(filepath)
        error("BDF文件不存在：%s", filepath);
    end

    cEEG = HyperEEG.MultiCH.core.BDFreader(char(filepath));

    if isempty(cEEG) || ~isfield(cEEG, 'data') || isempty(cEEG.data) || ...
            ~isfield(cEEG, 'times') || isempty(cEEG.times)
        error("BDF读取结果缺少data或times：%s", filepath);
    end

    [~, name, extension] = fileparts(filepath);
    EEGdata = struct();
    EEGdata.file.filename = string(name) + string(extension);
    EEGdata.file.rawpath = string(filepath);
    EEGdata.file.stage = "continuous_raw";
    EEGdata = HyperEEG.MultiCH.core.EEGdataSaver(EEGdata, cEEG);
    EEGdata.data = cEEG.data;
    EEGdata.times = double(cEEG.times(:)');

    if isfield(cEEG, 'event')
        EEGdata.event = addEventTime(cEEG.event, cEEG);
    else
        EEGdata.event = struct('type', {}, 'latency', {}, 'time_ms', {});
    end

    completedSteps = "bdf_import";

    if ~isempty(EEGdata.event)
        completedSteps(end + 1) = "marker_extract";
    end

    EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
        EEGdata, completedSteps, 1);

end


function events = addEventTime(events, EEG)
%ADDEVENTTIME 将EEGLAB样本索引显式转换为相对时间毫秒。

    if isempty(events)
        return;
    end

    firstTime_ms = double(EEG.times(1));

    for ievent = 1:numel(events)
        events(ievent).time_ms = firstTime_ms + ...
            (double(events(ievent).latency) - 1) / ...
            double(EEG.srate) * 1000;
    end

end

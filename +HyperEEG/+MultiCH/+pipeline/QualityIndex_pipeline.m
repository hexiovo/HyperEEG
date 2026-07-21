function [qualityTable, updatedFiles] = QualityIndex_pipeline( ...
        rawDir, segmentDir, artifactDir, cleanDir, logSwitch)
%QUALITYINDEX_PIPELINE 汇总各阶段文件状态并更新clean EEGdata。
%   只有存在可读取_clean.mat的记录标记为有效。缺失结果按最晚存在阶段
%   依次归因为数据切分、坏段处理或预处理阶段删除。

    if nargin < 5 || isempty(logSwitch)
        logSwitch = "on";
    end

    [logFile, logEnabled] = HyperEEG.MultiCH.misc.InitLogFile( ...
        [], "qualityindex", logSwitch);

    if logEnabled
        diary(char(logFile));
        diary on
        diaryCleanup = onCleanup(@() closeDiary()); %#ok<NASGU>
    end

    validateInputs(rawDir, segmentDir, artifactDir, cleanDir);
    fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf("开始汇总EEG数据质量\n");
    recordIds = readRecordIds(rawDir);
    nRecord = numel(recordIds);
    isValid = zeros(nRecord, 1);
    deletionReason = strings(nRecord, 1);
    badchannel = strings(nRecord, 1);
    channelRateText = strings(nRecord, 1);
    rate = nan(nRecord, 1);
    updatedFiles = strings(0, 1);

    for irecord = 1:nRecord
        recordId = recordIds(irecord);
        fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        fprintf("汇总第%d/%d条数据：%s\n", irecord, nRecord, recordId);
        cleanPath = findStageFile(cleanDir, recordId, "_clean.mat");
        segmentPath = findStageFile(segmentDir, recordId, "_segment.mat");
        artifactPath = findStageFile(artifactDir, recordId, "_artifact.mat");
        rawPath = findRawFile(rawDir, recordId);

        if strlength(cleanPath) > 0
            try
                loadedData = load(char(cleanPath));

                if ~isfield(loadedData, "EEGdata")
                    error("MAT文件缺少EEGdata变量。");
                end

                EEGdata = loadedData.EEGdata;
                [EEGdata, qualityInfo] = ...
                    HyperEEG.MultiCH.core.DataQualitySummary(EEGdata);

                saveEEGdata(cleanPath, EEGdata);
                updatedFiles(end + 1, 1) = cleanPath; %#ok<AGROW>
                isValid(irecord) = 1;
                badchannel(irecord) = formatBadChannels( ...
                    qualityInfo.badchannel);
                channelRateText(irecord) = formatChannelRates( ...
                    qualityInfo.channelrate, qualityInfo.badchannel);
                rate(irecord) = qualityInfo.totalEffectiveRate;
            catch ME
                qualityInfo = invalidInfo( ...
                    "质量汇总阶段失败：" + string(ME.message));
                deletionReason(irecord) = qualityInfo.deletionReason;
                warning("%s质量汇总失败：%s", recordId, ME.message);
            end
        elseif strlength(artifactPath) > 0
            qualityInfo = invalidInfo("预处理阶段删除");
            deletionReason(irecord) = qualityInfo.deletionReason;
        elseif strlength(segmentPath) > 0
            qualityInfo = invalidInfo("坏段处理阶段删除");
            deletionReason(irecord) = qualityInfo.deletionReason;
        elseif strlength(rawPath) > 0
            qualityInfo = invalidInfo("数据切分阶段删除");
            deletionReason(irecord) = qualityInfo.deletionReason;
        else
            qualityInfo = invalidInfo("未找到原始数据");
            deletionReason(irecord) = qualityInfo.deletionReason;
        end

    end

    qualityTable = table(recordIds, isValid, deletionReason, ...
        badchannel, channelRateText, rate, ...
        'VariableNames', {'recordId', 'isValid', 'deletionReason', ...
        'badchannel', 'channelRateText', 'rate'});
    fprintf('[%s]', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf("数据质量汇总完成：有效%d条，无效%d条，更新MAT文件%d个\n", ...
        sum(isValid), sum(isValid == 0), numel(updatedFiles));

end

function validateInputs(varargin)
%VALIDATEINPUTS 检查各阶段目录。

    for idir = 1:numel(varargin)
        if ~isfolder(varargin{idir})
            error("数据阶段目录不存在：%s", varargin{idir});
        end
    end

end

function recordIds = readRecordIds(rawDir)
%READRECORDIDS 从原始文件名提取三位数据序号。

    rawFiles = dir(rawDir);
    rawFiles = rawFiles(~[rawFiles.isdir]);
    recordIds = strings(0, 1);

    for ifile = 1:numel(rawFiles)
        matchedId = regexp(rawFiles(ifile).name, ...
            '^(\d{3})(?:\D|$)', 'tokens', 'once');

        if ~isempty(matchedId)
            recordIds(end + 1, 1) = string(matchedId{1}); %#ok<AGROW>
        end
    end

    recordIds = unique(recordIds, 'sorted');

    if isempty(recordIds)
        error("rawDir中没有以三位序号开头的原始数据文件：%s", rawDir);
    end

end

function filepath = findStageFile(stageDir, recordId, suffix)
%FINDSTAGEFILE 按序号和阶段后缀查找唯一结果。

    candidates = dir(fullfile(stageDir, ...
        char(recordId + "*" + suffix)));
    candidates = candidates(~[candidates.isdir]);

    if isempty(candidates)
        filepath = "";
    else
        [~, order] = sort({candidates.name});
        candidates = candidates(order);
        filepath = string(fullfile(candidates(1).folder, ...
            candidates(1).name));
    end

end

function filepath = findRawFile(rawDir, recordId)
%FINDRAWFILE 查找以三位序号开头的原始数据文件。

    candidates = dir(fullfile(rawDir, char(recordId + ".*")));
    candidates = candidates(~[candidates.isdir]);

    if isempty(candidates)
        filepath = "";
    else
        filepath = string(fullfile(candidates(1).folder, ...
            candidates(1).name));
    end

end

function qualityInfo = invalidInfo(reason)
%INVALIDINFO 构造无效记录的统一索引结构。

    qualityInfo = struct();
    qualityInfo.isValid = 0;
    qualityInfo.deletionReason = string(reason);
    qualityInfo.badchannel = zeros(1, 0);
    qualityInfo.channelrate = cell(0, 2);
    qualityInfo.totalEffectiveRate = NaN;

end

function saveEEGdata(outputPath, EEGdata)
%SAVEEEGDATA 先写同目录临时文件，再原子替换既有_clean.mat。

    [outputDir, outputName, outputExt] = fileparts(outputPath);
    temporaryPath = fullfile(outputDir, ...
        outputName + "_quality_tmp" + outputExt);

    if isfile(temporaryPath)
        delete(char(temporaryPath));
    end

    temporaryCleanup = onCleanup(@() deleteTemporary(temporaryPath)); %#ok<NASGU>
    save(char(temporaryPath), "EEGdata");
    [moveSuccess, moveMessage] = movefile( ...
        char(temporaryPath), char(outputPath), 'f');

    if ~moveSuccess
        error("替换MAT文件失败：%s", moveMessage);
    end

end

function deleteTemporary(temporaryPath)
%DELETETEMPORARY 清理异常路径遗留的临时MAT文件。

    if isfile(temporaryPath)
        delete(char(temporaryPath));
    end

end

function outputText = formatBadChannels(badChannels)
%FORMATBADCHANNELS 将坏导数组转换为逗号分隔文本。

    if isempty(badChannels)
        outputText = "无";
    else
        outputText = strjoin(string(badChannels), ",");
    end

end

function outputText = formatChannelRates(channelRateCell, badChannels)
%FORMATCHANNELRATES 仅为qualityTable/Excel展示生成ch1:98%;ch2:0文本。

    nChannel = size(channelRateCell, 1);
    channelText = strings(1, nChannel);

    for ichannel = 1:nChannel
        channelName = string(channelRateCell{ichannel, 1});
        rateValue = double(channelRateCell{ichannel, 2});

        if ismember(ichannel, badChannels)
            rateText = "0";
        else
            percentValue = rateValue * 100;

            if percentValue >= 99.5
                rateText = "100%";
            elseif percentValue >= 10
                rateText = string(sprintf('%.0f%%', percentValue));
            elseif percentValue >= 1
                rateText = string(sprintf('%.1f%%', percentValue));
            else
                rateText = string(sprintf('%.2f%%', percentValue));
            end
        end

        channelText(ichannel) = channelName + ":" + rateText;
    end

    outputText = strjoin(channelText, ";");

end

function closeDiary()
%CLOSEDIARY 确保退出时关闭日志。

    diary off

end

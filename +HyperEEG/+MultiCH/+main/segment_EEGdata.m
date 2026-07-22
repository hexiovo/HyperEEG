function outputFiles = segment_EEGdata(segmentinfo, inputDir, outputDir)
%SEGMENT_EEGDATA 按segmentinfo切割连续_artifact或_clean MAT数据。
%   用于“先坏段/预处理，后分段”流程；输入文件保持只读，输出名称以
%   _artifact_segment.mat或_clean_segment.mat结尾并保留处理历史。

    validateSegmentInfo(segmentinfo);

    if ~exist(inputDir, 'dir')
        error("连续MAT输入目录不存在：%s", inputDir);
    end

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    matFiles = HyperEEG.MultiCH.misc.getFiles(inputDir, 'mat');
    sourceFiles = matFiles(endsWith(matFiles, "_clean.mat", ...
        "IgnoreCase", true) | endsWith(matFiles, "_artifact.mat", ...
        "IgnoreCase", true));
    outputFiles = strings(0, 1);

    if isempty(sourceFiles)
        warning("输入目录中未找到连续_artifact.mat或_clean.mat：%s", inputDir);
        return;
    end

    validIndex = find(segmentinfo.dataflag == 1);

    for irecord = 1:numel(validIndex)
        HyperEEG.MultiCH.misc.WorkflowCancel("throw");
        infoIndex = validIndex(irecord);
        currentPlan = segmentinfo.segmentInterval(infoIndex);
        [~, rawName] = fileparts(currentPlan.filename);
        filepath = matchContinuousFile(sourceFiles, string(rawName));

        if strlength(filepath) == 0
            warning("找不到原始文件%s对应的连续预处理MAT，已跳过。", rawName);
            continue;
        end

        loadedData = load(char(filepath));

        if ~isfield(loadedData, 'EEGdata')
            warning("MAT文件中不存在EEGdata，已跳过：%s", filepath);
            continue;
        end

        sourceEEGdata = loadedData.EEGdata;
        validateEEGdata(sourceEEGdata, filepath);
        [~, inputName] = fileparts(filepath);
        stageName = sourceStage(inputName);
        baseName = regexprep(string(inputName), ...
            '_(clean|artifact)$', '', 'ignorecase');

        for isegment = 1:numel(currentPlan.intervals)
            HyperEEG.MultiCH.misc.WorkflowCancel("throw");
            currentSegment = currentPlan.intervals(isegment);

            if isempty(currentSegment.intervals)
                continue;
            end

            [segmentData, segmentTimes] = selectIntervals( ...
                sourceEEGdata, currentSegment.intervals);

            if isempty(segmentTimes)
                warning("%s的分段%s没有匹配到有效采样点，已跳过。", ...
                    rawName, currentSegment.name);
                continue;
            end

            EEGdata = sourceEEGdata;
            EEGdata.data = segmentData;
            EEGdata.times = segmentTimes;
            EEGdata.marker = currentSegment.intervals;
            EEGdata.segment.name = string(currentSegment.name);
            EEGdata.segment.intervals = currentSegment.intervals;
            EEGdata.segment.unit = "time_ms";
            EEGdata.segment.sourceDataPath = filepath;

            if isfield(segmentinfo, 'source')
                EEGdata.segment.planSource = segmentinfo.source;
            end

            completedSteps = "segment";

            if isfield(segmentinfo, 'source') && ...
                    isfield(segmentinfo.source, 'type') && ...
                    strcmpi(segmentinfo.source.type, "xlsx")
                completedSteps(end + 1) = "marker_import";
            else
                completedSteps(end + 1) = "marker_manual";
            end

            EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                EEGdata, completedSteps, 1);
            outputName = baseName + "_" + string(currentSegment.name) + ...
                "_" + stageName + "_segment.mat";
            outputPath = fullfile(string(outputDir), outputName);
            EEGdata.file.segmentname = string(currentSegment.name);
            EEGdata.file.segmentpath = outputPath;
            EEGdata.file.segmentSourceStage = stageName;
            save(char(outputPath), 'EEGdata');
            outputFiles(end + 1, 1) = outputPath; %#ok<AGROW>
        end
    end

end


function filepath = matchContinuousFile(sourceFiles, rawName)
%MATCHCONTINUOUSFILE 根据原始BDF基本名匹配连续阶段文件。

    matched = false(numel(sourceFiles), 1);

    for ifile = 1:numel(sourceFiles)
        [~, candidateName] = fileparts(sourceFiles(ifile));
        candidateBase = regexprep(string(candidateName), ...
            '_(clean|artifact)$', '', 'ignorecase');
        matched(ifile) = strcmpi(candidateBase, rawName);
    end

    index = find(matched);

    if numel(index) > 1
        error("连续数据目录中存在多个与%s匹配的文件。", rawName);
    elseif isempty(index)
        filepath = "";
    else
        filepath = sourceFiles(index);
    end

end


function stageName = sourceStage(inputName)
%SOURCESTAGE 返回用于输出命名的连续数据阶段。

    if endsWith(string(inputName), "_clean", "IgnoreCase", true)
        stageName = "clean";
    else
        stageName = "artifact";
    end

end


function [data, times] = selectIntervals(EEGdata, intervals)
%SELECTINTERVALS 选择多个时间区间并保持原时间轴缺口。

    selected = false(1, numel(EEGdata.times));

    for iinterval = 1:size(intervals, 1)
        selected = selected | (EEGdata.times >= intervals(iinterval, 1) & ...
            EEGdata.times <= intervals(iinterval, 2));
    end

    data = EEGdata.data(:, selected);
    times = EEGdata.times(selected);

end


function validateSegmentInfo(segmentinfo)
%VALIDATESEGMENTINFO 验证分段计划最小契约。

    if ~isstruct(segmentinfo) || ~isscalar(segmentinfo) || ...
            ~isfield(segmentinfo, 'segmentInterval') || ...
            ~isfield(segmentinfo, 'dataflag') || ...
            numel(segmentinfo.segmentInterval) ~= numel(segmentinfo.dataflag)
        error("segmentinfo结构无效或字段长度不一致。");
    end

end


function validateEEGdata(EEGdata, filepath)
%VALIDATEEEGDATA 验证连续MAT的数据和毫秒时间轴。

    if ~isstruct(EEGdata) || ~isscalar(EEGdata) || ...
            ~isfield(EEGdata, 'data') || ~isfield(EEGdata, 'times') || ...
            size(EEGdata.data, 2) ~= numel(EEGdata.times)
        error("连续MAT中的EEGdata无效：%s", filepath);
    end

end

function segmentinfo = SegmentPlanImport( ...
        planPath, markerList, preliminaryFlag)
%SEGMENTPLANIMPORT 从XLSX批量导入每个BDF的分段边界。
%   工作表优先使用segments，否则读取第一个工作表。每行表示一个区间：
%   file_name, segment_name, start, end, unit, enabled, notes。
%   unit必须为time_ms、time_s或sample_index；end允许填写end。
%   同一文件、同一segment_name可填写多行，重叠区间会统一合并。

    if nargin < 3 || isempty(preliminaryFlag)
        preliminaryFlag = ones(numel(markerList), 1);
    end

    % 部分工具箱会用同名函数覆盖MATLAB内置contains/narginchk等，进而使
    % sheetnames/readtable失败。这里只在本函数期间移除冲突目录，退出时
    % 由onCleanup恢复完整原路径，不改变后续EEGLAB/BIOSIG环境。
    pathCleanup = ...
        HyperEEG.MultiCH.misc.TemporarilyRemoveBuiltinShadows( ...
        "读取XLSX"); %#ok<NASGU>

    if ~isfile(planPath)
        error("SegmentPlanImport:PlanNotFound", ...
            "分段计划XLSX不存在：%s", planPath);
    end

    [~, ~, extension] = fileparts(planPath);

    if ~strcmpi(extension, '.xlsx')
        error("SegmentPlanImport:InvalidExtension", ...
            "分段计划必须为.xlsx文件：%s", planPath);
    end

    availableSheets = sheetnames(char(planPath));
    sheetName = availableSheets(1);
    preferredSheet = find(strcmpi(availableSheets, "segments"), 1);

    if ~isempty(preferredSheet)
        sheetName = availableSheets(preferredSheet);
    end

    try
        importOptions = detectImportOptions(char(planPath), ...
            'Sheet', char(sheetName), ...
            'VariableNamingRule', 'preserve');
        % end列允许同时出现数字与文本end，因此统一按string读取再显式校验。
        importOptions = setvartype(importOptions, ...
            importOptions.VariableNames, 'string');
        planTable = readtable(char(planPath), importOptions);
    catch ME
        error("SegmentPlanImport:ReadFailed", ...
            "无法读取分段计划%s（工作表%s）：%s", ...
            planPath, sheetName, ME.message);
    end

    columnNames = string(planTable.Properties.VariableNames);
    fileColumn = findColumn(columnNames, ...
        ["file_name", "filename", "file", "文件名"]);
    nameColumn = findColumn(columnNames, ...
        ["segment_name", "segment", "分段名称", "分段"]);
    startColumn = findColumn(columnNames, ...
        ["start", "start_position", "start_marker", ...
        "开始位置", "起始位置"]);
    endColumn = findColumn(columnNames, ...
        ["end", "end_position", "end_marker", ...
        "结束位置", "终止位置"]);
    unitColumn = findColumn(columnNames, ["unit", "单位"]);
    enabledColumn = findColumn(columnNames, ...
        ["enabled", "include", "是否启用", "有效"], false);

    requiredColumns = [fileColumn, nameColumn, startColumn, ...
        endColumn, unitColumn];

    if any(isnan(requiredColumns))
        error("SegmentPlanImport:MissingColumn", ...
            "XLSX缺少必需列。需要file_name、segment_name、start、end、unit。");
    end

    nfiles = numel(markerList);
    preliminaryFlag = preliminaryFlag(:);

    if numel(preliminaryFlag) ~= nfiles
        error("SegmentPlanImport:FlagSizeMismatch", ...
            "preliminaryFlag长度必须与markerList一致。");
    end

    rawSegments = repmat({struct('name', {}, 'start', {}, 'end', {})}, ...
        nfiles, 1);
    sourceRows = cell(nfiles, 1);

    for irow = 1:height(planTable)
        if ~isnan(enabledColumn) && ...
                ~parseEnabled(planTable{irow, enabledColumn})
            continue;
        end

        fileName = strtrim(cellText(planTable{irow, fileColumn}));
        segmentName = strtrim(cellText(planTable{irow, nameColumn}));
        unitName = lower(strtrim(cellText(planTable{irow, unitColumn})));

        if strlength(fileName) == 0 && strlength(segmentName) == 0
            continue;
        end

        if strlength(fileName) == 0 || strlength(segmentName) == 0
            error("SegmentPlanImport:IncompleteRow", ...
                "第%d行的file_name或segment_name为空。", irow + 1);
        end

        if ~isempty(regexp(char(segmentName), '[<>:"/\\|?*]', 'once'))
            error("SegmentPlanImport:InvalidSegmentName", ...
                "第%d行segment_name含文件名非法字符：%s", ...
                irow + 1, segmentName);
        end

        fileIndex = matchFile(fileName, markerList, irow + 1);
        startValue = parseBoundary(planTable{irow, startColumn}, ...
            false, irow + 1, "start");
        endValue = parseBoundary(planTable{irow, endColumn}, ...
            true, irow + 1, "end");

        [start_ms, end_ms] = convertToMilliseconds( ...
            startValue, endValue, unitName, markerList{fileIndex}, ...
            irow + 1);

        if start_ms < markerList{fileIndex}.firstTime_ms
            error("SegmentPlanImport:BeforeDataStart", ...
                "第%d行start早于数据起点（%.6f ms）。", ...
                irow + 1, markerList{fileIndex}.firstTime_ms);
        end

        if end_ms <= start_ms
            error("SegmentPlanImport:InvalidInterval", ...
                "第%d行end必须大于start。", irow + 1);
        end

        newSegment = struct('name', char(segmentName), ...
            'start', start_ms, 'end', end_ms);
        rawSegments{fileIndex}(end + 1) = newSegment;
        sourceRows{fileIndex}(end + 1) = irow + 1;
    end

    segmentInterval = repmat(struct('intervals', [], 'filename', ""), ...
        nfiles, 1);
    dataflag = zeros(nfiles, 1);

    for ifile = 1:nfiles
        segmentInterval(ifile).filename = markerList{ifile}.filename;

        if isempty(rawSegments{ifile})
            if preliminaryFlag(ifile) == 1
                warning("SegmentPlanImport:FileNotListed", ...
                    "XLSX未列出文件，已跳过：%s", ...
                    markerList{ifile}.filename);
            end
            continue;
        end

        if preliminaryFlag(ifile) ~= 1
            warning("SegmentPlanImport:PreliminaryRejected", ...
                "文件虽在XLSX中列出，但读取/忽略检查未通过，已跳过：%s", ...
                markerList{ifile}.filename);
            continue;
        end

        segmentInterval(ifile).intervals = ...
            HyperEEG.MultiCH.misc.Segmentmerge(rawSegments{ifile});
        dataflag(ifile) = 1;
    end

    segmentinfo.segmentInterval = segmentInterval;
    segmentinfo.dataflag = dataflag;
    segmentinfo.source.type = "xlsx";
    segmentinfo.source.path = string(planPath);
    segmentinfo.source.sheet = string(sheetName);
    segmentinfo.source.rows = sourceRows;
    segmentinfo.source.unit = "time_ms";

end

function columnIndex = findColumn(columnNames, aliases, required)
%FINDCOLUMN 根据规范化后的中英文别名查找列。

    if nargin < 3
        required = true;
    end

    normalizedNames = normalizeHeader(columnNames);
    normalizedAliases = normalizeHeader(aliases);
    columnIndex = find(ismember(normalizedNames, normalizedAliases), 1);

    if isempty(columnIndex)
        columnIndex = NaN;
    end

    if required && isnan(columnIndex)
        return;
    end

end


function normalized = normalizeHeader(value)
%NORMALIZEHEADER 忽略大小写、空格、连字符和下划线差异。

    normalized = lower(strtrim(string(value)));
    normalized = regexprep(normalized, '[\s_\-]+', '');

end


function fileIndex = matchFile(fileName, markerList, excelRow)
%MATCHFILE 支持完整路径、相对路径和唯一的文件基本名。

    requested = normalizePath(fileName);
    allPaths = strings(numel(markerList), 1);
    allNames = strings(numel(markerList), 1);

    for ifile = 1:numel(markerList)
        allPaths(ifile) = normalizePath(markerList{ifile}.filename);
        [~, name, extension] = fileparts(markerList{ifile}.filename);
        allNames(ifile) = lower(string(name) + string(extension));
    end

    exactIndex = find(allPaths == requested);

    if isempty(exactIndex) && contains(requested, "/")
        exactIndex = find(endsWith(allPaths, "/" + requested));
    end

    if isempty(exactIndex)
        [~, requestedName, requestedExtension] = fileparts(requested);

        if strlength(requestedExtension) == 0
            requestedBase = lower(string(requestedName));
            candidateBase = erase(allNames, ".bdf");
            exactIndex = find(candidateBase == requestedBase);
        else
            exactIndex = find(allNames == ...
                lower(string(requestedName) + string(requestedExtension)));
        end
    end

    if isempty(exactIndex)
        error("SegmentPlanImport:UnknownFile", ...
            "XLSX第%d行文件未在RawInputDir中找到：%s", ...
            excelRow, fileName);
    end

    if numel(exactIndex) > 1
        error("SegmentPlanImport:AmbiguousFile", ...
            "XLSX第%d行文件名对应多个BDF，请填写相对或完整路径：%s", ...
            excelRow, fileName);
    end

    fileIndex = exactIndex;

end


function normalized = normalizePath(pathValue)
%NORMALIZEPATH 统一路径分隔符并忽略大小写。

    normalized = lower(strrep(strtrim(string(pathValue)), "\", "/"));
    normalized = regexprep(normalized, '/+', '/');

end


function value = parseBoundary(rawValue, allowEnd, excelRow, fieldName)
%PARSEBOUNDARY 解析数值边界，end字段可使用文本end。

    valueText = strtrim(cellText(rawValue));

    if allowEnd && strcmpi(valueText, "end")
        value = Inf;
        return;
    end

    value = str2double(valueText);

    if ~isscalar(value) || isnan(value) || ~isfinite(value)
        boundaryHint = "";

        if allowEnd
            boundaryHint = "或end";
        end

        error("SegmentPlanImport:InvalidBoundary", ...
            "第%d行%s必须为有限数字%s。", excelRow, fieldName, ...
            boundaryHint);
    end

end


function [start_ms, end_ms] = convertToMilliseconds( ...
        startValue, endValue, unitName, fileInfo, excelRow)
%CONVERTTOMILLISECONDS 把XLSX边界显式转换为EEG.times使用的毫秒。

    switch lower(unitName)
        case {"time_ms", "ms", "毫秒"}
            scale = 1;
            offset = 0;
        case {"time_s", "s", "sec", "秒"}
            scale = 1000;
            offset = 0;
        case {"sample_index", "sample", "samples", "采样点", "样本索引"}
            if ~isfield(fileInfo, 'sampleRate') || ...
                    ~isfinite(fileInfo.sampleRate) || fileInfo.sampleRate <= 0
                error("SegmentPlanImport:MissingSampleRate", ...
                    "第%d行使用sample_index，但文件采样率不可用。", excelRow);
            end

            scale = 1000 / double(fileInfo.sampleRate);
            offset = double(fileInfo.firstTime_ms) - scale;
        otherwise
            error("SegmentPlanImport:UnknownUnit", ...
                "第%d行unit不支持：%s。请用time_ms、time_s或sample_index。", ...
                excelRow, unitName);
    end

    start_ms = startValue * scale + offset;

    if isinf(endValue)
        end_ms = Inf;
    else
        end_ms = endValue * scale + offset;
    end

end


function enabled = parseEnabled(rawValue)
%PARSEENABLED 空值默认启用，并接受常见中英文布尔值。

    valueText = lower(strtrim(cellText(rawValue)));

    if strlength(valueText) == 0 || ...
            any(valueText == ["1", "true", "yes", "y", "是", "启用"])
        enabled = true;
    elseif any(valueText == ["0", "false", "no", "n", "否", "禁用"])
        enabled = false;
    else
        error("SegmentPlanImport:InvalidEnabled", ...
            "enabled值无法识别：%s", valueText);
    end

end


function outputText = cellText(rawValue)
%CELLTEXT 把readtable返回的标量单元格安全转换为文本。

    if iscell(rawValue)
        rawValue = rawValue{1};
    end

    if ismissing(rawValue)
        outputText = "";
    elseif isnumeric(rawValue) || islogical(rawValue)
        outputText = string(rawValue);
    else
        outputText = string(rawValue);
    end

end

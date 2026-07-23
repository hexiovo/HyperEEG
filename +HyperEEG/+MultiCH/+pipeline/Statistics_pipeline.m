function summary = Statistics_pipeline(userOptions, progressCallback)
%STATISTICS_PIPELINE 批量计算个体水平统计并导出MAT与统计XLSX。
%   支持时域、频谱/频带及熵/非线性。MAT始终保存完整结果；XLSX可
%   关闭，频谱与峰列表可选长表、宽表、拆分工作簿或不导出。

    if nargin < 2 || isempty(progressCallback)
        progressCallback = @(message) fprintf('%s\n', message);
    end

    options = HyperEEG.MultiCH.main.StatisticsOptions(userOptions);
    inputDir = char(options.inputDir);
    outputDir = char(options.outputDir);

    if ~isfolder(inputDir)
        error("clean_data目录不存在：%s", inputDir);
    end

    if ~isfolder(outputDir)
        mkdir(outputDir);
    end

    files = dir(fullfile(inputDir, '**', '*.mat'));
    keep = contains(lower(string({files.name})), "_clean") & ...
        ~contains(lower(string({files.name})), "_statistics.mat") & ...
        ~contains(lower(string({files.name})), "_time_domain_statistics.mat");
    files = files(keep);

    if isempty(files)
        error("clean_data目录中未找到可分析的MAT文件。");
    end

    groupTable = readGroupTable(options.groupFile);
    allResults = table();
    allFrequencyScalar = table();
    allFrequencySpectrum = table();
    allFrequencyPeaks = table();
    allFrequencyPairs = table();
    allNonlinearScalar = table();
    allNonlinearSeries = table();
    rqaDenseRecords = cell(0, 1);
    completed = strings(0, 1);
    skipped = strings(0, 1);

    for ifile = 1:numel(files)
        sourcePath = fullfile(files(ifile).folder, files(ifile).name);
        progressCallback(sprintf('统计 %d/%d：%s', ...
            ifile, numel(files), files(ifile).name));

        try
            loaded = load(sourcePath, 'EEGdata');

            if ~isfield(loaded, 'EEGdata')
                error("MAT文件中不存在EEGdata变量。");
            end

            EEGdata = loaded.EEGdata;
            [sampleRate, channelNames] = validateEEGdata(EEGdata);
            [~, sourceStem] = fileparts(files(ifile).name);
            identifiers = lookupIdentifiers(groupTable, sourceStem);
            segmentName = inferSegmentName(EEGdata, sourceStem);
            resultTable = table();
            frequencyScalar = table();
            frequencySpectrum = table();
            frequencyPeaks = table();
            frequencyPairs = table();
            nonlinearScalar = table();
            nonlinearSeries = table();
            timeInfo = struct();
            frequencyInfo = struct();
            frequencyDetails = {};
            nonlinearInfo = struct();
            nonlinearDetails = {};

            if options.timeDomain.enabled
                [resultTable, timeInfo] = ...
                    HyperEEG.MultiCH.core.TimeDomainStatistics( ...
                    EEGdata.data, sampleRate, options);
                resultTable.channel_name = channelNames(:);
                resultTable = movevars(resultTable, 'channel_name', ...
                    'After', 'channel_index');
                resultTable = addIdentifiers(resultTable, files(ifile).name, ...
                    identifiers, segmentName);
            end

            if options.frequency.enabled
                [frequencyScalar, frequencySpectrum, frequencyPeaks, ...
                    frequencyPairs, frequencyDetails, frequencyInfo] = ...
                    HyperEEG.MultiCH.core.FrequencyStatistics( ...
                    EEGdata.data, sampleRate, options, channelNames);
                frequencyScalar.channel_name = channelNames(:);
                frequencyScalar = movevars(frequencyScalar, 'channel_name', ...
                    'After', 'channel_index');
                frequencyScalar = addIdentifiers(frequencyScalar, ...
                    files(ifile).name, identifiers, segmentName);
                frequencySpectrum = addChannelIdentifiers( ...
                    frequencySpectrum, channelNames, files(ifile).name, ...
                    identifiers, segmentName);
                frequencyPeaks = addChannelIdentifiers(frequencyPeaks, ...
                    channelNames, files(ifile).name, identifiers, segmentName);
                if ~isempty(frequencyPairs)
                    frequencyPairs = addIdentifiers(frequencyPairs, ...
                        files(ifile).name, identifiers, segmentName);
                end
            end

            if options.nonlinear.enabled
                [nonlinearScalar, nonlinearSeries, nonlinearDetails, ...
                    nonlinearInfo] = HyperEEG.MultiCH.core.NonlinearStatistics( ...
                    EEGdata.data, sampleRate, options);
                nonlinearScalar.channel_name = channelNames(:);
                nonlinearScalar = movevars(nonlinearScalar, 'channel_name', ...
                    'After', 'channel_index');
                nonlinearScalar = addIdentifiers(nonlinearScalar, ...
                    files(ifile).name, identifiers, segmentName);

                if ~isempty(nonlinearSeries)
                    nonlinearSeries.channel_name = ...
                        channelNames(nonlinearSeries.channel_index);
                    nonlinearSeries = movevars(nonlinearSeries, ...
                        'channel_name', 'After', 'channel_index');
                    nonlinearSeries = addIdentifiers(nonlinearSeries, ...
                        files(ifile).name, identifiers, segmentName);
                end

                if options.nonlinear.rqa.exportMatrixToExcel && ...
                        options.nonlinear.rqa.matrixExcelMode == "dense"
                    for ichannel = 1:numel(nonlinearDetails)
                        if isstruct(nonlinearDetails{ichannel}) && ...
                                isfield(nonlinearDetails{ichannel}, 'rqa') && ...
                                isfield(nonlinearDetails{ichannel}.rqa, ...
                                'recurrenceMatrix')
                            record.source_file = string(files(ifile).name);
                            record.subject_id = identifiers.subject_id;
                            record.group = identifiers.group;
                            record.dyad_id = identifiers.dyad_id;
                            record.session = identifiers.session;
                            record.condition = identifiers.condition;
                            record.segment = segmentName;
                            record.channel_index = ichannel;
                            record.channel_name = channelNames(ichannel);
                            record.matrix = nonlinearDetails{ichannel}.rqa.recurrenceMatrix;
                            rqaDenseRecords{end + 1, 1} = record; %#ok<AGROW>
                        end
                    end
                end
            end

            Results = struct();
            Results.level = "individual";
            Results.analysis = enabledAnalyses(options);
            Results.sourceFile = string(sourcePath);
            Results.createdAt = datetime('now');
            Results.identifiers = identifiers;
            Results.segmentName = segmentName;
            Results.options = options;

            if options.timeDomain.enabled
                Results.timeDomain.info = timeInfo;
                Results.timeDomain.data = resultTable;
                Results.calculation = timeInfo;
                Results.data = resultTable;
            end

            if options.frequency.enabled
                Results.frequency.info = frequencyInfo;
                Results.frequency.scalar = frequencyScalar;
                Results.frequency.spectrum = frequencySpectrum;
                Results.frequency.periodicPeaks = frequencyPeaks;
                Results.frequency.faa = frequencyPairs;
                Results.frequency.details = frequencyDetails;
            end

            if options.nonlinear.enabled
                Results.nonlinear.info = nonlinearInfo;
                Results.nonlinear.scalar = nonlinearScalar;
                Results.nonlinear.series = nonlinearSeries;
                Results.nonlinear.details = nonlinearDetails;
            end

            matPath = fullfile(outputDir, sourceStem + outputSuffix(options));
            save(char(matPath), 'Results');

            if ~isempty(resultTable)
                allResults = [allResults; resultTable]; %#ok<AGROW>
            end

            if ~isempty(frequencyScalar)
                allFrequencyScalar = [allFrequencyScalar; frequencyScalar]; %#ok<AGROW>
            end
            if ~isempty(frequencySpectrum)
                allFrequencySpectrum = [allFrequencySpectrum; frequencySpectrum]; %#ok<AGROW>
            end
            if ~isempty(frequencyPeaks)
                allFrequencyPeaks = [allFrequencyPeaks; frequencyPeaks]; %#ok<AGROW>
            end
            if ~isempty(frequencyPairs)
                allFrequencyPairs = [allFrequencyPairs; frequencyPairs]; %#ok<AGROW>
            end

            if ~isempty(nonlinearScalar)
                allNonlinearScalar = [allNonlinearScalar; nonlinearScalar]; %#ok<AGROW>
            end

            if ~isempty(nonlinearSeries)
                allNonlinearSeries = [allNonlinearSeries; nonlinearSeries]; %#ok<AGROW>
            end

            completed(end + 1) = string(sourcePath); %#ok<AGROW>
        catch ME
            skipped(end + 1) = string(sourcePath) + " | " + ...
                string(ME.message); %#ok<AGROW>
            progressCallback("跳过：" + string(files(ifile).name) + ...
                "（" + string(ME.message) + "）");
        end
    end

    if isempty(allResults) && isempty(allFrequencyScalar) && ...
            isempty(allNonlinearScalar)
        error("没有文件成功产生统计结果。首个错误：%s", skipped(1));
    end

    excelPath = "";
    excelPaths = strings(0, 1);
    if options.excel.enabled
        [excelPath, excelPaths] = exportExcel(options, outputDir, ...
            allResults, allFrequencyScalar, allFrequencySpectrum, ...
            allFrequencyPeaks, allFrequencyPairs, allNonlinearScalar, ...
            allNonlinearSeries, rqaDenseRecords, completed, skipped);
    end

    summary.completedFiles = completed;
    summary.skippedFiles = skipped;
    summary.resultTable = allResults;
    summary.frequencyScalarTable = allFrequencyScalar;
    summary.frequencySpectrumTable = allFrequencySpectrum;
    summary.frequencyPeakTable = allFrequencyPeaks;
    summary.frequencyPairTable = allFrequencyPairs;
    summary.nonlinearScalarTable = allNonlinearScalar;
    summary.nonlinearSeriesTable = allNonlinearSeries;
    summary.excelPath = string(excelPath);
    summary.excelPaths = excelPaths;
    summary.outputDir = string(outputDir);
    progressCallback(sprintf(['统计完成：%d个文件，时域%d行，频谱标量%d行，', ...
        'PSD%d行，周期峰%d行，FAA%d行，非线性标量%d行，序列%d行。'], ...
        numel(completed), height(allResults), height(allFrequencyScalar), ...
        height(allFrequencySpectrum), height(allFrequencyPeaks), ...
        height(allFrequencyPairs), height(allNonlinearScalar), ...
        height(allNonlinearSeries)));

end


function [excelPath, excelPaths] = exportExcel(options, outputDir, ...
        timeTable, frequencyScalar, frequencySpectrum, frequencyPeaks, ...
        frequencyPairs, nonlinearScalar, nonlinearSeries, rqaDenseRecords, ...
        completed, skipped)
    excelPath = fullfile(outputDir, options.excelName + ".xlsx");
    temporaryPath = fullfile(outputDir, ...
        "." + options.excelName + "_writing.xlsx");
    if isfile(temporaryPath), delete(temporaryPath); end
    excelPaths = string(excelPath);

    if options.timeDomain.enabled
        timeLong = scalarToLong(timeTable);
        switch options.excel.timeDomainLayout
            case "wide"
                if sum([options.timeDomain.enabled, options.frequency.enabled, ...
                        options.nonlinear.enabled]) > 1
                    timeSheet = 'TimeDomain';
                else
                    timeSheet = 'Results';
                end
                writetable(timeTable, temporaryPath, 'Sheet', timeSheet);
            case "long"
                writetable(timeLong, temporaryPath, 'Sheet', 'TimeDomainLong');
            case "both"
                writetable(timeTable, temporaryPath, 'Sheet', 'TimeDomainWide');
                writetable(timeLong, temporaryPath, 'Sheet', 'TimeDomainLong');
        end
    end

    if options.frequency.enabled
        writetable(frequencyScalar, temporaryPath, 'Sheet', 'FrequencyScalar');
        if ~isempty(frequencyPairs)
            writetable(frequencyPairs, temporaryPath, 'Sheet', 'FrequencyPairs');
        end
    end

    if options.nonlinear.enabled
        nonlinearLong = scalarToLong(nonlinearScalar);
        switch options.excel.nonlinearScalarLayout
            case "wide"
                writetable(nonlinearScalar, temporaryPath, ...
                    'Sheet', 'NonlinearScalar');
            case "long"
                writetable(nonlinearLong, temporaryPath, ...
                    'Sheet', 'NonlinearScalarLong');
            case "both"
                writetable(nonlinearScalar, temporaryPath, ...
                    'Sheet', 'NonlinearScalarWide');
                writetable(nonlinearLong, temporaryPath, ...
                    'Sheet', 'NonlinearScalarLong');
        end

        rqaRows = false(height(nonlinearSeries), 1);
        if ~isempty(nonlinearSeries)
            rqaRows = nonlinearSeries.metric == "rqa_recurrence";
        end
        regularSeries = nonlinearSeries(~rqaRows, :);
        rqaCoordinates = nonlinearSeries(rqaRows, :);
        switch options.excel.nonlinearSeriesMode
            case "long"
                writeTableChunks(regularSeries, temporaryPath, ...
                    "NonlinearSeries", options.excel.maxRowsPerSheet);
            case "wide"
                nonlinearWide = seriesToWide(regularSeries);
                if ~isempty(nonlinearWide)
                    writetable(nonlinearWide, temporaryPath, ...
                        'Sheet', 'NonlinearSeriesWide');
                end
            case "separate"
                if ~isempty(regularSeries)
                    seriesPath = fullfile(outputDir, ...
                        options.excelName + "_nonlinear_series.xlsx");
                    writeSeparateWorkbook(regularSeries, seriesPath, ...
                        "NonlinearSeries", options.excel.maxRowsPerSheet);
                    excelPaths(end + 1) = string(seriesPath); %#ok<AGROW>
                end
        end

        if options.nonlinear.rqa.exportMatrixToExcel
            if options.nonlinear.rqa.matrixExcelMode == "dense"
                if ~isempty(rqaDenseRecords)
                    densePath = fullfile(outputDir, ...
                        options.excelName + "_rqa_matrices.xlsx");
                    writeDenseRqaWorkbook(rqaDenseRecords, densePath);
                    excelPaths(end + 1) = string(densePath); %#ok<AGROW>
                end
            elseif ~isempty(rqaCoordinates)
                if options.excel.rqaLocation == "separate"
                    rqaPath = fullfile(outputDir, ...
                        options.excelName + "_rqa_coordinates.xlsx");
                    writeSeparateWorkbook(rqaCoordinates, rqaPath, ...
                        "RQACoordinates", options.excel.maxRowsPerSheet);
                    excelPaths(end + 1) = string(rqaPath); %#ok<AGROW>
                else
                    writeTableChunks(rqaCoordinates, temporaryPath, ...
                        "RQACoordinates", options.excel.maxRowsPerSheet);
                end
            end
        end
    end

    if options.frequency.enabled && options.excel.psdMode ~= "none"
        sampledSpectrum = frequencySpectrum( ...
            1:options.excel.spectrumStride:height(frequencySpectrum), :);
        switch options.excel.psdMode
            case "long"
                writeTableChunks(sampledSpectrum, temporaryPath, ...
                    "FrequencySpectrum", options.excel.maxRowsPerSheet);
            case "wide"
                wideSpectrum = spectrumToWide(sampledSpectrum);
                if ~isempty(wideSpectrum)
                    writetable(wideSpectrum, temporaryPath, ...
                        'Sheet', 'FrequencySpectrumWide');
                end
            case "separate"
                if ~isempty(sampledSpectrum)
                    spectrumPath = fullfile(outputDir, ...
                        options.excelName + "_frequency_spectrum.xlsx");
                    writeSeparateWorkbook(sampledSpectrum, spectrumPath, ...
                        "FrequencySpectrum", options.excel.maxRowsPerSheet);
                    excelPaths(end + 1) = string(spectrumPath); %#ok<AGROW>
                end
        end
    end

    if options.frequency.enabled && ...
            options.excel.periodicPeakMode ~= "none"
        switch options.excel.periodicPeakMode
            case "long"
                writeTableChunks(frequencyPeaks, temporaryPath, ...
                    "PeriodicPeaks", options.excel.maxRowsPerSheet);
            case "wide"
                widePeaks = peaksToWide(frequencyPeaks);
                if ~isempty(widePeaks)
                    writetable(widePeaks, temporaryPath, ...
                        'Sheet', 'PeriodicPeaksWide');
                end
            case "separate"
                if ~isempty(frequencyPeaks)
                    peakPath = fullfile(outputDir, ...
                        options.excelName + "_periodic_peaks.xlsx");
                    writeSeparateWorkbook(frequencyPeaks, peakPath, ...
                        "PeriodicPeaks", options.excel.maxRowsPerSheet);
                    excelPaths(end + 1) = string(peakPath); %#ok<AGROW>
                end
        end
    end

    settingsTable = makeSettingsTable(options, completed, skipped);
    writetable(settingsTable, temporaryPath, 'Sheet', 'Settings');
    movefile(temporaryPath, excelPath, 'f');
end


function longTable = scalarToLong(wideTable)
    longTable = table();
    if isempty(wideTable), return; end
    qualityNames = ["source_file", "subject_id", "group", "dyad_id", ...
        "session", "condition", "segment", "channel_index", ...
        "channel_name", "n_total", "n_original", "n_valid", ...
        "missing_fraction", "effective_duration_s", "missing_status", ...
        "status"];
    variables = string(wideTable.Properties.VariableNames);
    keyNames = qualityNames(ismember(qualityNames, variables));
    metricNames = variables(~ismember(variables, keyNames));
    for metric = metricNames
        block = wideTable(:, cellstr(keyNames));
        block.metric = repmat(metric, height(wideTable), 1);
        block.value = double(wideTable.(char(metric)));
        longTable = [longTable; block]; %#ok<AGROW>
    end
end


function wide = seriesToWide(series)
    wide = table();
    if isempty(series), return; end
    keyNames = {'source_file', 'subject_id', 'group', 'dyad_id', ...
        'session', 'condition', 'segment', 'channel_index', 'channel_name', ...
        'metric', 'index_name', 'value_name'};
    [groupIndex, keys] = findgroups(series(:, keyNames));
    indices = unique(series.index_value, 'sorted');
    if width(keys) + numel(indices) > 16384
        error("5.3序列wide模式超过Excel列上限，请改用long或separate。");
    end
    values = nan(height(keys), numel(indices));
    [~, indexColumn] = ismember(series.index_value, indices);
    for irow = 1:height(series)
        values(groupIndex(irow), indexColumn(irow)) = series.value(irow);
    end
    labels = replace(compose('%.8g', indices), [".", "-", "+"], ...
        ["p", "m", ""]);
    names = matlab.lang.makeUniqueStrings( ...
        matlab.lang.makeValidName("index_" + labels));
    wide = [keys, array2table(values, 'VariableNames', cellstr(names))];
end


function writeDenseRqaWorkbook(records, pathValue)
    [folder, name, extension] = fileparts(pathValue);
    temporaryPath = fullfile(folder, "." + string(name) + ...
        "_writing" + string(extension));
    if isfile(temporaryPath), delete(temporaryPath); end
    n = numel(records);
    sheetName = strings(n, 1);
    sourceFile = strings(n, 1);
    subjectId = strings(n, 1);
    group = strings(n, 1);
    dyadId = strings(n, 1);
    session = strings(n, 1);
    condition = strings(n, 1);
    segment = strings(n, 1);
    channelIndex = zeros(n, 1);
    channelName = strings(n, 1);
    matrixSize = zeros(n, 1);
    for irecord = 1:n
        record = records{irecord};
        sheetName(irecord) = "RQA_" + compose('%04d', irecord);
        sourceFile(irecord) = record.source_file;
        subjectId(irecord) = record.subject_id;
        group(irecord) = record.group;
        dyadId(irecord) = record.dyad_id;
        session(irecord) = record.session;
        condition(irecord) = record.condition;
        segment(irecord) = record.segment;
        channelIndex(irecord) = record.channel_index;
        channelName(irecord) = record.channel_name;
        matrix = double(record.matrix);
        matrixSize(irecord) = size(matrix, 1);
        columnNames = "col_" + string(1:size(matrix, 2));
        matrixTable = array2table(matrix, ...
            'VariableNames', cellstr(columnNames));
        matrixTable = addvars(matrixTable, (1:size(matrix, 1))', ...
            'Before', 1, 'NewVariableNames', 'row_index');
        writetable(matrixTable, temporaryPath, ...
            'Sheet', char(sheetName(irecord)));
    end
    indexTable = table(sheetName, sourceFile, subjectId, group, dyadId, ...
        session, condition, segment, channelIndex, channelName, matrixSize, ...
        'VariableNames', {'sheet_name', 'source_file', 'subject_id', ...
        'group', 'dyad_id', 'session', 'condition', 'segment', ...
        'channel_index', 'channel_name', 'matrix_size'});
    writetable(indexTable, temporaryPath, 'Sheet', 'RQA_Index');
    movefile(temporaryPath, pathValue, 'f');
end


function writeSeparateWorkbook(tableValue, pathValue, sheetBase, maxRows)
    [folder, name, extension] = fileparts(pathValue);
    temporaryPath = fullfile(folder, "." + string(name) + ...
        "_writing" + string(extension));
    if isfile(temporaryPath), delete(temporaryPath); end
    writeTableChunks(tableValue, temporaryPath, sheetBase, maxRows);
    movefile(temporaryPath, pathValue, 'f');
end


function writeTableChunks(tableValue, workbookPath, sheetBase, maxRows)
    if isempty(tableValue), return; end
    rowsPerSheet = maxRows - 1;
    chunkCount = ceil(height(tableValue) / rowsPerSheet);
    for ichunk = 1:chunkCount
        firstRow = (ichunk - 1) * rowsPerSheet + 1;
        lastRow = min(height(tableValue), ichunk * rowsPerSheet);
        if chunkCount == 1
            sheetName = char(sheetBase);
        else
            sheetName = char(extractBefore(sheetBase, min(strlength(sheetBase) + 1, 27)) + ...
                "_" + string(ichunk));
        end
        writetable(tableValue(firstRow:lastRow, :), workbookPath, ...
            'Sheet', sheetName);
    end
end


function wide = spectrumToWide(spectrum)
    wide = table();
    if isempty(spectrum), return; end
    keyNames = {'source_file', 'subject_id', 'group', 'dyad_id', ...
        'session', 'condition', 'segment', 'channel_index', 'channel_name'};
    [groupIndex, keys] = findgroups(spectrum(:, keyNames));
    frequencies = unique(spectrum.frequency_hz, 'sorted');
    if width(keys) + 2 * numel(frequencies) > 16384
        error(["wide模式超过Excel的16384列上限；请改用long、separate或", ...
            "增大PSD频点步长。"]) ;
    end
    powerMatrix = nan(height(keys), numel(frequencies));
    dbMatrix = nan(height(keys), numel(frequencies));
    [~, frequencyIndex] = ismember(spectrum.frequency_hz, frequencies);
    for irow = 1:height(spectrum)
        powerMatrix(groupIndex(irow), frequencyIndex(irow)) = spectrum.power(irow);
        dbMatrix(groupIndex(irow), frequencyIndex(irow)) = spectrum.power_db_hz(irow);
    end
    labels = replace(compose('%.6g', frequencies), [".", "-", "+"], ...
        ["p", "m", ""]);
    powerNames = matlab.lang.makeUniqueStrings( ...
        matlab.lang.makeValidName("power_hz_" + labels));
    dbNames = matlab.lang.makeUniqueStrings( ...
        matlab.lang.makeValidName("power_db_hz_" + labels));
    values = array2table([powerMatrix, dbMatrix], ...
        'VariableNames', cellstr([powerNames; dbNames]));
    wide = [keys, values];
end


function wide = peaksToWide(peaks)
    wide = table();
    if isempty(peaks), return; end
    keyNames = {'source_file', 'subject_id', 'group', 'dyad_id', ...
        'session', 'condition', 'segment', 'channel_index', 'channel_name'};
    [groupIndex, keys] = findgroups(peaks(:, keyNames));
    peakCount = max(peaks.peak_index);
    values = nan(height(keys), 3 * peakCount);
    names = strings(1, 3 * peakCount);
    for ipeak = 1:peakCount
        offset = (ipeak - 1) * 3;
        names(offset + (1:3)) = ["peak" + ipeak + "_frequency_hz", ...
            "peak" + ipeak + "_excess_log10", ...
            "peak" + ipeak + "_bandwidth_hz"];
    end
    for irow = 1:height(peaks)
        offset = (peaks.peak_index(irow) - 1) * 3;
        values(groupIndex(irow), offset + (1:3)) = [ ...
            peaks.center_frequency_hz(irow), peaks.peak_excess_log10(irow), ...
            peaks.bandwidth_hz(irow)];
    end
    wide = [keys, array2table(values, 'VariableNames', cellstr(names))];
end


function [sampleRate, channelNames] = validateEEGdata(EEGdata)
    if ~isstruct(EEGdata) || ~isfield(EEGdata, 'data') || ...
            ~isnumeric(EEGdata.data) || isempty(EEGdata.data)
        error("EEGdata.data必须为非空数值矩阵。");
    end

    sampleRate = NaN;

    if isfield(EEGdata, 'etc') && isfield(EEGdata.etc, 'samplerate')
        rateInfo = EEGdata.etc.samplerate;

        if isfield(rateInfo, 'clean') && isfinite(rateInfo.clean)
            sampleRate = double(rateInfo.clean);
        elseif isfield(rateInfo, 'raw') && isfinite(rateInfo.raw)
            sampleRate = double(rateInfo.raw);
        end
    end

    if ~isfinite(sampleRate) || sampleRate <= 0
        if isfield(EEGdata, 'times') && numel(EEGdata.times) > 1
            timeStepMs = median(diff(double(EEGdata.times)), 'omitnan');
            sampleRate = 1000 / timeStepMs;
        end
    end

    if ~isfinite(sampleRate) || sampleRate <= 0
        error("无法从EEGdata中确定有效采样率。");
    end

    nChannel = size(EEGdata.data, 1);
    channelNames = "Ch" + string((1:nChannel)');

    if isfield(EEGdata, 'etc') && isfield(EEGdata.etc, 'channel') && ...
            isfield(EEGdata.etc.channel, 'info')
        info = EEGdata.etc.channel.info;

        if isstruct(info) && isfield(info, 'labels') && numel(info) >= nChannel
            labels = string({info(1:nChannel).labels})';
            labels(strlength(strtrim(labels)) == 0) = ...
                channelNames(strlength(strtrim(labels)) == 0);
            channelNames = labels;
        end
    end
end


function groupTable = readGroupTable(groupFile)
    groupTable = table();

    if strlength(groupFile) == 0
        return;
    end

    if ~isfile(groupFile)
        error("分组XLSX不存在：%s", groupFile);
    end

    groupTable = readtable(groupFile, 'VariableNamingRule', 'preserve', ...
        'TextType', 'string');

    if isempty(groupTable)
        return;
    end

    normalized = lower(string(groupTable.Properties.VariableNames));
    normalized = replace(normalized, [" ", "-", "."], "_");
    groupTable.Properties.VariableNames = cellstr(normalized);
    fileColumn = find(ismember(normalized, ...
        ["file_name", "filename", "file", "文件名", "名称"]), 1);

    if isempty(fileColumn)
        error("分组XLSX必须包含file_name列。");
    end

    if normalized(fileColumn) ~= "file_name"
        groupTable.Properties.VariableNames{fileColumn} = 'file_name';
    end

    if ismember('enabled', groupTable.Properties.VariableNames)
        enabled = groupTable.enabled;

        if isstring(enabled) || iscellstr(enabled)
            enabled = ismember(lower(string(enabled)), ...
                ["1", "true", "yes", "y", "是", "启用"]);
        else
            enabled = logical(enabled);
        end

        groupTable = groupTable(enabled, :);
    end
end


function identifiers = lookupIdentifiers(groupTable, sourceStem)
    identifiers.subject_id = "";
    identifiers.group = "";
    identifiers.dyad_id = "";
    identifiers.session = "";
    identifiers.condition = "";

    if isempty(groupTable)
        return;
    end

    sourceKeys = comparisonKeys(sourceStem);
    rowIndex = [];

    for irow = 1:height(groupTable)
        candidate = string(groupTable.file_name(irow));

        if any(ismember(sourceKeys, comparisonKeys(candidate)))
            rowIndex = irow;
            break;
        end
    end

    if isempty(rowIndex)
        return;
    end

    names = fieldnames(identifiers);

    for iname = 1:numel(names)
        name = names{iname};

        if ismember(name, groupTable.Properties.VariableNames)
            identifiers.(name) = string(groupTable.(name)(rowIndex));
        end
    end
end


function keys = comparisonKeys(value)
    [~, value] = fileparts(char(string(value)));
    base = lower(string(value));
    stripped = regexprep(base, ...
        '(_clean_segment|_clean|_segment|_artifact)$', '');
    keys = unique([base, stripped]);
end


function resultTable = addIdentifiers(resultTable, sourceFile, identifiers, segment)
    n = height(resultTable);
    prefix = table(repmat(string(sourceFile), n, 1), ...
        repmat(string(identifiers.subject_id), n, 1), ...
        repmat(string(identifiers.group), n, 1), ...
        repmat(string(identifiers.dyad_id), n, 1), ...
        repmat(string(identifiers.session), n, 1), ...
        repmat(string(identifiers.condition), n, 1), ...
        repmat(string(segment), n, 1), ...
        'VariableNames', {'source_file', 'subject_id', 'group', ...
        'dyad_id', 'session', 'condition', 'segment'});
    resultTable = [prefix, resultTable];
end


function resultTable = addChannelIdentifiers(resultTable, channelNames, ...
        sourceFile, identifiers, segment)
    if isempty(resultTable), return; end
    resultTable.channel_name = channelNames(resultTable.channel_index);
    resultTable = movevars(resultTable, 'channel_name', ...
        'After', 'channel_index');
    resultTable = addIdentifiers(resultTable, sourceFile, identifiers, segment);
end


function segmentName = inferSegmentName(EEGdata, sourceStem)
    segmentName = "";

    if isfield(EEGdata, 'segment') && isscalar(string(EEGdata.segment))
        segmentName = string(EEGdata.segment);
    elseif isfield(EEGdata, 'name') && isscalar(string(EEGdata.name))
        segmentName = string(EEGdata.name);
    else
        token = regexp(sourceStem, ...
            '_([^_]+)_clean(?:_segment)?$', 'tokens', 'once');

        if ~isempty(token)
            segmentName = string(token{1});
        end
    end
end


function settings = makeSettingsTable(options, completed, skipped)
    timeMetrics = "";
    frequencyMetrics = "";
    nonlinearMetrics = "";

    if options.timeDomain.enabled
        timeMetrics = strjoin(options.timeDomain.metrics, ",");
    end

    if options.nonlinear.enabled
        nonlinearMetrics = strjoin(options.nonlinear.metrics, ",");
    end

    if options.frequency.enabled
        frequencyMetrics = strjoin(options.frequency.metrics, ",");
    end

    parameter = [ ...
        "analysis"; "created_at"; "input_dir"; "output_dir"; ...
        "group_file"; "enabled_analyses"; "time_domain_metrics"; ...
        "frequency_metrics"; "frequency_bands"; "excel_enabled"; ...
        "excel_psd_mode"; "excel_periodic_peak_mode"; ...
        "excel_spectrum_stride"; ...
        "time_domain_layout"; "time_quantile_method"; "time_mad_method"; ...
        "time_shape_bias_correction"; "time_zero_cross_reference"; ...
        "nonlinear_metrics"; "nonlinear_scalar_layout"; ...
        "nonlinear_series_mode"; "nonlinear_spectral_method"; ...
        "entropy_standardization"; "entropy_distance"; ...
        "differential_entropy_method"; "rqa_distance"; ...
        "rqa_matrix_excel_mode"; "rqa_location"; "missing_method"; ...
        "max_missing_fraction"; "minimum_valid_samples"; ...
        "completed_file_count"; "skipped_file_count"];
    value = [ ...
        strjoin(enabledAnalyses(options), ","); string(datetime('now')); ...
        options.inputDir; options.outputDir; options.groupFile; ...
        strjoin(enabledAnalyses(options), ","); ...
        timeMetrics; frequencyMetrics; formatBands(options.frequency); ...
        string(options.excel.enabled); options.excel.psdMode; ...
        options.excel.periodicPeakMode; ...
        string(options.excel.spectrumStride); ...
        options.excel.timeDomainLayout; options.timeDomain.quantileMethod; ...
        options.timeDomain.madMethod; options.timeDomain.shapeBiasCorrection; ...
        options.timeDomain.zeroCrossReference; nonlinearMetrics; ...
        options.excel.nonlinearScalarLayout; ...
        options.excel.nonlinearSeriesMode; options.nonlinear.spectral.method; ...
        options.nonlinear.entropy.standardization; ...
        options.nonlinear.entropy.distance; ...
        options.nonlinear.differential.method; ...
        options.nonlinear.rqa.distance; ...
        options.nonlinear.rqa.matrixExcelMode; options.excel.rqaLocation; ...
        options.missing.method; ...
        string(options.missing.maxFraction); ...
        string(options.missing.minimumValidSamples); ...
        string(numel(completed)); string(numel(skipped))];
    settings = table(parameter, value);
end


function analyses = enabledAnalyses(options)
    analyses = strings(0, 1);
    if options.timeDomain.enabled, analyses(end + 1) = "time_domain"; end
    if options.frequency.enabled, analyses(end + 1) = "frequency_band"; end
    if options.nonlinear.enabled, analyses(end + 1) = "entropy_nonlinear"; end
end


function suffix = outputSuffix(options)
    enabledCount = sum([options.timeDomain.enabled, options.frequency.enabled, ...
        options.nonlinear.enabled]);
    if enabledCount > 1
        suffix = "_statistics.mat";
    elseif options.frequency.enabled
        suffix = "_frequency_statistics.mat";
    elseif options.nonlinear.enabled
        suffix = "_entropy_nonlinear_statistics.mat";
    else
        suffix = "_time_domain_statistics.mat";
    end
end


function value = formatBands(frequencyOptions)
    names = frequencyOptions.bands.names;
    ranges = frequencyOptions.bands.rangesHz;
    items = strings(numel(names), 1);
    for iband = 1:numel(names)
        items(iband) = names(iband) + ":" + string(ranges(iband, 1)) + ...
            "-" + string(ranges(iband, 2)) + "Hz";
    end
    value = strjoin(items, ";");
end

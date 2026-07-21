function [outsegment, cancelbool] = ...
        SegmentEditor(EEGdata, currentfilename, nSeg)
%SEGMENTEDITOR 人工录入坏导编号与坏时间区间。
%   Channel=0表示全部通道，Channel>0表示单通道；Start/End使用
%   EEGdata.times的单位。关闭窗口等同取消，不会静默确认为空标记。

    if nargin < 3 || isempty(nSeg)
        nSeg = 5;
    end

    outsegment = [];
    cancelbool = 0;
    selectedRows = [];
    nChannel = size(EEGdata.data, 1);

    %%==========================================================
    % 打开EEG窗口
    %%==========================================================

    % 清理上一次异常中遗留的查看器，保证每个文件只对应一个EEG窗口。
    staleFigure = findall(groot, ...
        'Type', 'figure', 'Tag', 'HyperEEGPlot');

    if ~isempty(staleFigure)
        delete(staleFigure);
    end

    eegFigure = [];

    try
        eegFigure = HyperEEG.MultiCH.main.PlotEEGData(EEGdata, nSeg);
    catch ME
        % PlotEEGData可能在Figure创建后报错，必须清理孤立窗口再向上抛出。
        orphanFigure = findall(groot, ...
            'Type', 'figure', 'Tag', 'HyperEEGPlot');

        if ~isempty(orphanFigure)
            delete(orphanFigure);
        end

        rethrow(ME);
    end

    %%==========================================================
    % 经典Figure编辑窗口，避免uifigure WebController异常
    %%==========================================================

    fig = figure( ...
        'Name', char(string(currentfilename) + "  Segment Editor"), ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Color', 'w', ...
        'Position', [300 100 760 500], ...
        'CloseRequestFcn', @(~, ~) safeExit(1));

    uicontrol(fig, ...
        'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.04 0.925 0.92 0.045], ...
        'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left', ...
        'String', ['Channel填写0到通道总数；0表示全部通道。', ...
        'End可填写数字或end；只填写Channel表示整条通道。']);

    segmentTable = uitable(fig, ...
        'Units', 'normalized', ...
        'Position', [0.04 0.18 0.92 0.73], ...
        'Data', {'', '', ''}, ...
        'ColumnName', {'Channel', 'Start', 'End'}, ...
        'ColumnEditable', [true true true], ...
        'ColumnWidth', {260 190 190}, ...
        'RowName', 'numbered', ...
        'CellSelectionCallback', @selectRow);

    uicontrol(fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.04 0.10 0.18 0.055], ...
        'String', '+ Add Segment', ...
        'Callback', @addSegment);

    uicontrol(fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.24 0.10 0.18 0.055], ...
        'String', '- Delete Selected', ...
        'Callback', @deleteSegment);

    uicontrol(fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.58 0.04 0.17 0.075], ...
        'String', 'Confirm', ...
        'Callback', @confirmFcn);

    uicontrol(fig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.79 0.04 0.17 0.075], ...
        'String', 'Cancel', ...
        'Callback', @(~, ~) safeExit(1));

    drawnow;
    figure(fig);

    % 只有确认、取消或关闭窗口后才允许Pipeline继续
    uiwait(fig);

    %%==========================================================
    % 表格操作
    %%==========================================================

    function selectRow(~, eventData)
        % 记录表格当前选择行，供删除按钮使用。

        if isempty(eventData.Indices)
            selectedRows = [];
        else
            selectedRows = unique(eventData.Indices(:, 1));
        end

    end

    function addSegment(~, ~)
        % 添加一行空白输入，不直接修改EEGdata。

        tableData = segmentTable.Data;
        tableData(end + 1, :) = {'', '', ''};
        segmentTable.Data = tableData;

    end

    function deleteSegment(~, ~)
        % 删除选中行；未选择时给出明确提示。

        if isempty(selectedRows)
            return;
        end

        tableData = segmentTable.Data;
        validRows = selectedRows(selectedRows <= size(tableData, 1));
        tableData(validRows, :) = [];

        if isempty(tableData)
            tableData = {'', '', ''};
        end

        segmentTable.Data = tableData;
        selectedRows = [];

    end

    %%==========================================================
    % 确认并验证输入
    %%==========================================================

    function confirmFcn(~, ~)
        % 校验通道、边界、顺序和数据范围后生成标准标记结构。

        tableData = segmentTable.Data;
        currentSegment = struct('name', {}, 'start', {}, 'end', {});

        for irow = 1:size(tableData, 1)
            nameValue = normalizeText(tableData{irow, 1});
            startValue = normalizeText(tableData{irow, 2});
            endValue = normalizeText(tableData{irow, 3});

            if strlength(nameValue) == 0 && ...
                    strlength(startValue) == 0 && ...
                    strlength(endValue) == 0
                continue;
            end

            if strlength(nameValue) > 0 && ...
                    strlength(startValue) == 0 && ...
                    strlength(endValue) == 0
                % 只填写Channel表示覆盖整份数据；Inf避免长记录超过固定上限。
                startNumber = min(double(EEGdata.times(:)));
                endNumber = inf;
            else
                if strlength(nameValue) == 0 || ...
                        strlength(startValue) == 0 || ...
                        strlength(endValue) == 0
                    showInputError(sprintf( ...
                        '第%d行信息未填写完整。', irow));
                    return;
                end

                startNumber = str2double(startValue);

                if isnan(startNumber)
                    showInputError(sprintf( ...
                        '第%d行Start不是有效数字。', irow));
                    return;
                end

                if strcmpi(endValue, "end")
                    endNumber = inf;
                else
                    endNumber = str2double(endValue);

                    if isnan(endNumber)
                        showInputError(sprintf( ...
                            '第%d行End不是有效数字或end。', irow));
                        return;
                    end
                end

                if endNumber <= startNumber
                    showInputError(sprintf( ...
                        '第%d行End必须大于Start。', irow));
                    return;
                end
            end

            channelNumber = str2double(nameValue);

            if isnan(channelNumber) || channelNumber < 0 || ...
                    channelNumber > nChannel || ...
                    channelNumber ~= fix(channelNumber)
                showInputError(sprintf( ...
                    '第%d行Channel必须是0到%d之间的整数，0表示全部通道。', ...
                    irow, nChannel));
                return;
            end

            currentSegment(end + 1) = struct( ...
                'name', char(string(channelNumber)), ...
                'start', startNumber, ...
                'end', endNumber); %#ok<AGROW>
        end

        channelNumber = str2double({currentSegment.name});

        if any(channelNumber == 0)
            confirmChoice = questdlg( ...
                ['Channel 0会处理全部通道。', ...
                '只填写Channel 0时将排除整个文件，且不进入后续流程，', ...
                '是否继续？'], ...
                'Confirm Channel 0', ...
                'Continue', 'Return', 'Return');

            if ~strcmp(confirmChoice, 'Continue')
                return;
            end
        end

        outsegment = currentSegment;
        safeExit(0);

    end

    function value = normalizeText(value)
        % 将table可能返回的char/string/numeric统一为去空格文本。

        if isempty(value)
            value = "";
        elseif isnumeric(value) && isscalar(value)
            value = string(value);
        elseif ischar(value) || (isstring(value) && isscalar(value))
            value = strtrim(string(value));
        else
            value = "";
        end

    end

    function showInputError(messageText)
        % 使用模态错误框阻止带错误的人工标记进入后续切割。

        errorDialog = errordlg(messageText, 'Input Error', 'modal');

        if ~isempty(errorDialog) && isvalid(errorDialog)
            uiwait(errorDialog);
        end

    end

    %%==========================================================
    % 统一退出与EEG窗口维护
    %%==========================================================

    function safeExit(isCancel)
        % 统一处理确认、取消和右上角关闭，保证UI资源正确释放。

        % 优先关闭本文件对应的EEG Figure，避免最后残留空白波形窗口。
        if ~isempty(eegFigure) && isgraphics(eegFigure)
            delete(eegFigure);
        end

        if isCancel
            cancelbool = 1;
            outsegment = [];
        end

        if isvalid(fig)
            uiresume(fig);
            delete(fig);
        end

    end

end

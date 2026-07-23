function app = WorkflowUI(varargin)
%WORKFLOWUI HyperEEG统一工作流与完整参数配置界面。
%   app = WorkflowUI()打开界面；两个主按钮分别执行先分段或先预处理。
%   WorkflowUI('Visible','off')可用于自动化界面构建检查。

    parser = inputParser;
    addParameter(parser, 'Visible', 'on', ...
        @(value) any(strcmpi(string(value), ["on", "off"])));
    parse(parser, varargin{:});
    visible = char(parser.Results.Visible);

    colors.primary = [0.118, 0.227, 0.373];
    colors.secondary = [0.145, 0.388, 0.922];
    colors.success = [0.020, 0.588, 0.412];
    colors.background = [0.973, 0.980, 0.988];
    colors.surface = [1, 1, 1];
    colors.text = [0.059, 0.090, 0.165];
    colors.muted = [0.392, 0.455, 0.545];
    isRunning = false;

    fig = uifigure('Name', 'HyperEEG Workflow', ...
        'Position', [80, 60, 1220, 820], ...
        'Color', colors.background, 'Visible', visible, ...
        'CloseRequestFcn', @requestClose);
    root = uigridlayout(fig, [3, 1]);
    root.RowHeight = {64, '1x', 76};
    root.Padding = [16, 12, 16, 12];
    root.RowSpacing = 10;

    %% 顶部标题
    header = uipanel(root, 'BorderType', 'none', ...
        'BackgroundColor', colors.primary);
    headerLayout = uigridlayout(header, [2, 1]);
    headerLayout.RowHeight = {30, 22};
    headerLayout.Padding = [18, 7, 18, 5];
    headerLayout.BackgroundColor = colors.primary;
    uilabel(headerLayout, 'Text', 'HyperEEG 工作流控制台', ...
        'FontSize', 20, 'FontWeight', 'bold', ...
        'FontColor', [1, 1, 1]);
    uilabel(headerLayout, ...
        'Text', '自主选择阶段顺序；连续数据优先可避免每个小片段重复人工ICA', ...
        'FontSize', 12, 'FontColor', [0.88, 0.93, 0.98]);

    tabs = uitabgroup(root);
    workflowTab = uitab(tabs, 'Title', '流程与路径');
    artifactTab = uitab(tabs, 'Title', '坏段参数');
    preprocessTab = uitab(tabs, 'Title', '预处理参数');
    logTab = uitab(tabs, 'Title', '运行日志');

    controls = struct();
    controls.mainTabs = tabs;
    controls.artifactTab = artifactTab;
    buildWorkflowTab();
    buildArtifactTab();
    buildPreprocessTab();
    buildLogTab();

    %% 底部主操作区
    footer = uipanel(root, 'BorderType', 'line', ...
        'BackgroundColor', colors.surface);
    footerLayout = uigridlayout(footer, [1, 6]);
    footerLayout.ColumnWidth = {'1x', 190, 190, 150, 170, 110};
    footerLayout.Padding = [14, 10, 14, 10];
    controls.statusLabel = uilabel(footerLayout, ...
        'Text', '就绪：请选择路径并确认参数', ...
        'FontColor', colors.muted, 'FontSize', 12);
    controls.runSegmentFirst = uibutton(footerLayout, 'push', ...
        'Text', '运行：先分段', 'Tag', 'RunSegmentFirst', ...
        'FontWeight', 'bold', ...
        'FontColor', [1, 1, 1], ...
        'BackgroundColor', colors.secondary, ...
        'Tooltip', '分段 → 坏段 → 预处理（原流程）', ...
        'ButtonPushedFcn', @(~, ~) runOrder("segment_first"));
    controls.runPreprocessFirst = uibutton(footerLayout, 'push', ...
        'Text', '运行：先预处理', 'Tag', 'RunPreprocessFirst', ...
        'FontWeight', 'bold', ...
        'FontColor', [1, 1, 1], ...
        'BackgroundColor', colors.success, ...
        'Tooltip', '连续BDF坏段/预处理 → 最后分段，避免重复ICA', ...
        'ButtonPushedFcn', @(~, ~) runOrder("preprocess_first"));
    controls.openGuide = uibutton(footerLayout, 'push', ...
        'Text', '打开操作说明', 'Tag', 'OpenWorkflowGuide', ...
        'Tooltip', '打开txt目录中的PDF操作说明', ...
        'ButtonPushedFcn', @openWorkflowGuide);
    controls.statistics = uibutton(footerLayout, 'push', ...
        'Text', '统计分析', 'Tag', 'OpenStatisticsUI', ...
        'Tooltip', '打开独立统计分析与导出控制台', ...
        'ButtonPushedFcn', @(~, ~) ...
        HyperEEG.MultiCH.main.StatisticsUI());
    controls.close = uibutton(footerLayout, 'push', ...
        'Text', '关闭', 'ButtonPushedFcn', @requestClose);

    app.Figure = fig;
    app.Controls = controls;
    app.getConfig = @collectConfig;
    drawnow;

    function buildWorkflowTab()
        layout = createScrollableGrid(workflowTab, [1, 2], 680);
        layout.ColumnWidth = {360, '1x'};
        layout.Padding = [14, 14, 14, 14];
        layout.ColumnSpacing = 14;

        flowPanel = uipanel(layout, 'Title', '阶段与顺序', ...
            'FontWeight', 'bold', 'BackgroundColor', colors.surface);
        flowGrid = uigridlayout(flowPanel, [10, 1]);
        flowGrid.RowHeight = {28, 36, 36, 36, 20, 86, 86, '1x', 24, 24};
        flowGrid.Padding = [14, 12, 14, 12];
        uilabel(flowGrid, 'Text', '启用阶段', 'FontWeight', 'bold', ...
            'FontColor', colors.text);
        controls.stageSegment = uicheckbox(flowGrid, ...
            'Text', 'Marker检查与数据分段', 'Value', true);
        controls.stageArtifact = uicheckbox(flowGrid, ...
            'Text', '坏段自动识别与人工复核', 'Value', true);
        controls.stagePreprocess = uicheckbox(flowGrid, ...
            'Text', '脑电预处理与人工ICA', 'Value', true);
        uilabel(flowGrid, 'Text', '两个运行入口', 'FontWeight', 'bold', ...
            'FontColor', colors.text);
        createInfoCard(flowGrid, '先分段', ...
            '原流程：先产生多个_segment.mat，再逐文件坏段和预处理。每个小片段可能分别进入人工ICA。', ...
            [0.93, 0.96, 1.00]);
        createInfoCard(flowGrid, '先预处理（推荐用于长连续记录）', ...
            'BDF连续数据先坏段、ASR和人工ICA；每份BDF完成一次后，再按Marker切割_clean连续数据。', ...
            [0.92, 0.98, 0.95]);
        uilabel(flowGrid, 'Text', '日志', 'FontWeight', 'bold', ...
            'FontColor', colors.text);
        controls.logSwitch = uidropdown(flowGrid, ...
            'Items', {'on', 'off'}, 'Value', 'on');

        pathPanel = uipanel(layout, 'Title', '输入与阶段输出目录', ...
            'FontWeight', 'bold', 'BackgroundColor', colors.surface);
        pathGrid = uigridlayout(pathPanel, [7, 4]);
        pathGrid.RowHeight = repmat({38}, 1, 7);
        pathGrid.ColumnWidth = {150, '1x', 82, 220};
        pathGrid.Padding = [14, 14, 14, 14];
        pathGrid.RowSpacing = 10;
        controls.rawInput = addPathRow(pathGrid, 1, '原始BDF目录 *', ...
            true, '包含待处理BDF，可递归搜索');
        controls.segmentOutput = addPathRow(pathGrid, 2, '分段输出目录 *', ...
            true, '保存segmentinfo及最终分段');
        controls.artifactOutput = addPathRow(pathGrid, 3, '坏段输出目录 *', ...
            true, '保存_artifact.mat');
        controls.cleanOutput = addPathRow(pathGrid, 4, '预处理输出目录 *', ...
            true, '保存_clean.mat');
        controls.ignorePath = addPathRow(pathGrid, 5, '忽略名单XLSX', ...
            false, '可留空；文件名不含.bdf');
        controls.segmentPlanPath = addPathRow(pathGrid, 6, '分段计划XLSX', ...
            false, '可留空，留空时打开人工Marker界面');
        hintLabel = uilabel(pathGrid, 'Text', '提示', ...
            'FontWeight', 'bold');
        hintLabel.Layout.Row = 7;
        hintLabel.Layout.Column = 1;
        note = uilabel(pathGrid, 'Text', ...
            '各阶段目录应分开。原始BDF始终只读；取消人工界面不会写成功状态。', ...
            'WordWrap', 'on', 'FontColor', colors.muted);
        note.Layout.Row = 7;
        note.Layout.Column = [2, 4];
    end

    function buildArtifactTab()
        grid = createScrollableGrid(artifactTab, [16, 3], 780);
        grid.ColumnWidth = {250, 180, '1x'};
        grid.RowHeight = repmat({38}, 1, 16);
        grid.Padding = [18, 16, 18, 16];
        grid.RowSpacing = 8;

        controls.artifactInputType = addDropdown(grid, 1, ...
            '输入类型', {'auto', 'bdf', 'segment'}, 'auto', ...
            '统一工作流运行时由顺序自动设置', false);
        controls.artifactAutoEnabled = addCheckbox(grid, 2, ...
            '自动坏段识别', true, '关闭后不执行滑动窗口检测');
        controls.artifactManualEnabled = addCheckbox(grid, 3, ...
            '人工时域复核', true, '关闭后不打开波形与坏段编辑器');
        controls.artifactApplyEnabled = addCheckbox(grid, 4, ...
            '应用坏段标记', true, '关闭时仅保存标记，不删除或屏蔽数据');
        controls.windowDuration = addNumeric(grid, 5, ...
            '窗口长度（秒）', 2, '连续块内滑动窗口长度');
        controls.windowOverlap = addNumeric(grid, 6, ...
            '窗口重叠比例', 0.5, '范围0到小于1');
        controls.robustZThreshold = addNumeric(grid, 7, ...
            '普通异常阈值（Robust Z）', 6, '越小越敏感');
        controls.severeZThreshold = addNumeric(grid, 8, ...
            '严重异常阈值（Robust Z）', 10, '必须大于普通阈值');
        controls.minMetricVotes = addNumeric(grid, 9, ...
            '最少指标票数', 2, '整数1–4');
        controls.minBadChannelRatio = addNumeric(grid, 10, ...
            '最少异常通道比例', 0.25, '范围大于0且不超过1');
        controls.covarianceZThreshold = addNumeric(grid, 11, ...
            '协方差异常阈值', 6, '多通道联合分布变化阈值');
        controls.covarianceRegularization = addNumeric(grid, 12, ...
            '协方差正则化', 1e-6, '保证低通道协方差稳定');
        controls.flatScaleRatio = addNumeric(grid, 13, ...
            '平线尺度比例', 1e-4, '小于通道参考尺度的比例');
        controls.mergeGap = addNumeric(grid, 14, ...
            '合并间隔（秒）', 0.25, '相邻坏窗口的最大合并间隔');
        controls.minWindowCount = addNumeric(grid, 15, ...
            '最少窗口数', 8, '不足时不执行自动判别');
        info = uilabel(grid, 'Text', ...
            'BDF输入会先转换为连续EEGdata；Marker与绝对采集元数据保留，原文件不修改。', ...
            'WordWrap', 'on', 'FontColor', colors.muted);
        info.Layout.Row = 16;
        info.Layout.Column = [1, 3];
    end

    function buildPreprocessTab()
        subTabs = uitabgroup(preprocessTab);
        signalTab = uitab(subTabs, 'Title', '信号步骤');
        autoTab = uitab(subTabs, 'Title', '自动伪迹');
        manualTab = uitab(subTabs, 'Title', '人工复核');
        controls.preprocessTabs = subTabs;
        controls.signalTab = signalTab;
        controls.autoTab = autoTab;
        controls.manualTab = manualTab;

        signalGrid = createScrollableGrid(signalTab, [17, 3], 800);
        signalGrid.ColumnWidth = {250, 190, '1x'};
        signalGrid.RowHeight = repmat({36}, 1, 17);
        signalGrid.Padding = [18, 16, 18, 16];
        signalGrid.RowSpacing = 8;
        controls.preprocessInputType = addDropdown(signalGrid, 1, ...
            '输入类型', {'auto', 'bdf', 'artifact', 'segment'}, 'auto', ...
            '统一工作流运行时由顺序自动设置', false);
        controls.resampleEnabled = addCheckbox(signalGrid, 2, ...
            '启用重采样', false, '目标采样率必须满足分析频率要求');
        controls.targetRate = addNumeric(signalGrid, 3, ...
            '目标采样率（Hz）', 250, '常见值250或256');
        controls.detrendEnabled = addCheckbox(signalGrid, 4, ...
            '启用去趋势', true, '按连续时间块分别执行');
        controls.detrendMethod = addDropdown(signalGrid, 5, ...
            '去趋势方法', {'linear', 'constant'}, 'linear', ...
            'linear移除线性趋势；constant只去均值', true);
        controls.bandpassEnabled = addCheckbox(signalGrid, 6, ...
            '启用带通滤波', true, '零相位Butterworth');
        controls.bandpassProfile = addDropdown(signalGrid, 7, ...
            '带通预设', {'broadband', 'connectivity', 'erp', ...
            'time_frequency', 'slow', 'custom'}, 'broadband', ...
            'custom时必须填写下方范围', true);
        controls.bandpassRange = addText(signalGrid, 8, ...
            '自定义范围（Hz）', '', '示例：[1 40]；非custom可留空');
        controls.bandpassOrder = addNumeric(signalGrid, 9, ...
            '带通阶数', 4, '正整数，常见2–4');
        controls.notchEnabled = addCheckbox(signalGrid, 10, ...
            '启用工频Notch', true, '中国大陆通常为50 Hz');
        controls.lineFrequency = addNumeric(signalGrid, 11, ...
            '工频中心（Hz）', 50, '50或60');
        controls.notchBandwidth = addNumeric(signalGrid, 12, ...
            'Notch带宽（Hz）', 2, '总阻带宽度');
        controls.notchOrder = addNumeric(signalGrid, 13, ...
            'Notch阶数', 2, '正整数');
        controls.referenceEnabled = addCheckbox(signalGrid, 14, ...
            '启用重参考', false, '低通道数据需要明确研究依据');
        controls.referenceMethod = addDropdown(signalGrid, 15, ...
            '重参考方法', {'median', 'average', 'channel', 'none'}, ...
            'median', 'ICA前不能使用非线性median参考', true);
        controls.referenceChannels = addText(signalGrid, 16, ...
            '参考通道', '', 'channel方法示例：[1 2]；其余可留空');
        label = uilabel(signalGrid, 'Text', ...
            '所有开关和参数将完整写入EEGdata.preprocessing.options。', ...
            'FontColor', colors.muted);
        label.Layout.Row = 17;
        label.Layout.Column = [1, 3];

        autoGrid = createScrollableGrid(autoTab, [14, 3], 720);
        autoGrid.ColumnWidth = {250, 190, '1x'};
        autoGrid.RowHeight = repmat({38}, 1, 14);
        autoGrid.Padding = [18, 16, 18, 16];
        autoGrid.RowSpacing = 8;
        controls.preArtifactEnabled = addCheckbox(autoGrid, 1, ...
            '启用预处理伪迹模块', true, '总开关；关闭后自动和人工均跳过');
        controls.preAutoEnabled = addCheckbox(autoGrid, 2, ...
            '启用自动伪迹处理', true, '按勾选顺序robust → ASR → ICA');
        controls.methodRobust = addCheckbox(autoGrid, 3, ...
            '自动方法：robust', true, '局部中位数与MAD修复极端值');
        controls.methodASR = addCheckbox(autoGrid, 4, ...
            '自动方法：ASR', true, '需要EEGLAB clean_rawdata插件');
        controls.methodICA = addCheckbox(autoGrid, 5, ...
            '自动方法：ICA', false, '与下方人工ICA不同，低通道谨慎使用');
        controls.robustZ = addNumeric(autoGrid, 6, ...
            'robust阈值', 8, '常见6–10');
        controls.robustWindow = addNumeric(autoGrid, 7, ...
            'robust窗口（秒）', 1, '常见0.5–2');
        controls.icaKurtosisZ = addNumeric(autoGrid, 8, ...
            '自动ICA峰度阈值', 6, '常见4–8');
        controls.icaHighFrequencyZ = addNumeric(autoGrid, 9, ...
            '自动ICA高频阈值', 6, '常见4–8');
        controls.icaMaxRejectFraction = addNumeric(autoGrid, 10, ...
            '自动ICA最大删除比例', 0.25, '范围0–1');
        controls.icaRejectComponents = addText(autoGrid, 11, ...
            '指定自动ICA成分', '', '示例：[1 3]；留空自动判断');
        controls.autoICAMaxTrainingSamples = addNumeric(autoGrid, 12, ...
            '自动ICA最大训练点数', 100000, ...
            '长记录均匀抽样估计权重，再应用到全部数据');
        controls.asrBurstCriterion = addNumeric(autoGrid, 13, ...
            'ASR BurstCriterion', 20, '常见10–30，越小越严格');
        controls.asrMaxMemory = addNumeric(autoGrid, 14, ...
            'ASR最大内存（MB）', 512, '常见256、512、1024');

        manualGrid = createScrollableGrid(manualTab, [6, 3], 680);
        manualGrid.ColumnWidth = {250, 190, '1x'};
        manualGrid.RowHeight = {42, 42, 42, 96, 96, '1x'};
        manualGrid.Padding = [18, 16, 18, 16];
        controls.icaManualEnabled = addCheckbox(manualGrid, 1, ...
            '启用人工ICA成分复核', true, ...
            '连续优先流程中每份BDF只进入一次，新增坏导时仍可能重跑');
        controls.manualICAMaxTrainingSamples = addNumeric(manualGrid, 2, ...
            '人工ICA最大训练点数', 100000, ...
            '数百万点记录不再全部送入runica；最少1000');
        controls.frequencyManualEnabled = addCheckbox(manualGrid, 3, ...
            '启用最终通道频域复核', true, ...
            '检查PSD、整条坏导和可疑频段');
        createInfoCard(manualGrid, '人工ICA原则', ...
            '8通道分离证据有限。联合时间形态、PSD和通道权重判断；不确定成分应保留。', ...
            [0.93, 0.96, 1.00], [1, 3]);
        createInfoCard(manualGrid, '连续优先的收益', ...
            '选择“先预处理”时，ICA在长连续记录上完成，随后切段；不会为lecture、rest等每个小段重复打开界面。', ...
            [0.92, 0.98, 0.95], [1, 3]);
    end

    function buildLogTab()
        layout = createScrollableGrid(logTab, [2, 1], 680);
        layout.RowHeight = {34, '1x'};
        layout.Padding = [14, 14, 14, 14];
        top = uigridlayout(layout, [1, 2]);
        top.ColumnWidth = {'1x', 110};
        uilabel(top, 'Text', '界面日志仅显示阶段状态；详细文件日志仍写入log目录。', ...
            'FontColor', colors.muted);
        uibutton(top, 'Text', '清空显示', ...
            'ButtonPushedFcn', @(~, ~) set(controls.logArea, 'Value', {''}));
        controls.logArea = uitextarea(layout, 'Editable', 'off', ...
            'FontName', 'Consolas', 'Value', {'等待运行。'});
    end

    function field = addPathRow(grid, row, labelText, directoryMode, helpText)
        label = uilabel(grid, 'Text', labelText, 'FontWeight', 'bold');
        label.Layout.Row = row;
        label.Layout.Column = 1;
        field = uieditfield(grid, 'text');
        field.Layout.Row = row;
        field.Layout.Column = 2;
        button = uibutton(grid, 'Text', '浏览', ...
            'ButtonPushedFcn', @(~, ~) browsePath(field, directoryMode));
        button.Layout.Row = row;
        button.Layout.Column = 3;
        helper = uilabel(grid, 'Text', helpText, 'FontColor', colors.muted, ...
            'WordWrap', 'on');
        helper.Layout.Row = row;
        helper.Layout.Column = 4;
    end

    function browsePath(field, directoryMode)
        if directoryMode
            selected = uigetdir(pwd, '选择目录');

            if ~isequal(selected, 0)
                field.Value = selected;
            end
        else
            [file, folder] = uigetfile({'*.xlsx', 'Excel工作簿 (*.xlsx)'}, ...
                '选择XLSX文件');

            if ~isequal(file, 0)
                field.Value = fullfile(folder, file);
            end
        end
    end

    function openWorkflowGuide(~, ~)
        projectRoot = fileparts(fileparts(fileparts(fileparts( ...
            mfilename('fullpath')))));
        guidePath = fullfile(projectRoot, 'txt', ...
            'HyperEEG全流程操作说明.pdf');

        if ~isfile(guidePath)
            uialert(fig, "未找到操作说明：" + string(guidePath), ...
                '文件不存在', 'Icon', 'error');
            return;
        end

        try
            if ispc
                winopen(guidePath);
            else
                open(guidePath);
            end
            appendStatus("已打开操作说明：" + string(guidePath));
        catch ME
            uialert(fig, ME.message, '无法打开操作说明', 'Icon', 'error');
        end
    end

    function control = addNumeric(grid, row, labelText, value, helpText)
        addFieldLabel(grid, row, labelText, helpText);
        control = uieditfield(grid, 'numeric', 'Value', value);
        control.Layout.Row = row;
        control.Layout.Column = 2;
    end

    function control = addText(grid, row, labelText, value, helpText)
        addFieldLabel(grid, row, labelText, helpText);
        control = uieditfield(grid, 'text', 'Value', value);
        control.Layout.Row = row;
        control.Layout.Column = 2;
    end

    function control = addDropdown(grid, row, labelText, items, value, ...
            helpText, enabled)
        addFieldLabel(grid, row, labelText, helpText);
        control = uidropdown(grid, 'Items', items, 'Value', value);
        control.Layout.Row = row;
        control.Layout.Column = 2;

        if ~enabled
            control.Enable = 'off';
        end
    end

    function control = addCheckbox(grid, row, labelText, value, helpText)
        label = uilabel(grid, 'Text', labelText, 'FontWeight', 'bold');
        label.Layout.Row = row;
        label.Layout.Column = 1;
        control = uicheckbox(grid, 'Text', '启用', 'Value', value);
        control.Layout.Row = row;
        control.Layout.Column = 2;
        helper = uilabel(grid, 'Text', helpText, 'FontColor', colors.muted, ...
            'WordWrap', 'on');
        helper.Layout.Row = row;
        helper.Layout.Column = 3;
    end

    function addFieldLabel(grid, row, labelText, helpText)
        label = uilabel(grid, 'Text', labelText, 'FontWeight', 'bold');
        label.Layout.Row = row;
        label.Layout.Column = 1;
        helper = uilabel(grid, 'Text', helpText, 'FontColor', colors.muted, ...
            'WordWrap', 'on');
        helper.Layout.Row = row;
        helper.Layout.Column = 3;
    end

    function createInfoCard(parent, titleText, bodyText, background, columns)
        if nargin < 5
            columns = 1;
        end

        card = uipanel(parent, 'BorderType', 'line', ...
            'BackgroundColor', background);

        if numel(columns) == 2
            card.Layout.Column = columns;
        end

        cardLayout = uigridlayout(card, [2, 1]);
        cardLayout.RowHeight = {24, '1x'};
        cardLayout.Padding = [12, 8, 12, 8];
        cardLayout.BackgroundColor = background;
        uilabel(cardLayout, 'Text', titleText, 'FontWeight', 'bold', ...
            'FontColor', colors.text);
        uilabel(cardLayout, 'Text', bodyText, 'WordWrap', 'on', ...
            'FontColor', colors.muted);
    end

    function grid = createScrollableGrid(parent, gridSize, ~)
        % R2023a的uigridlayout自身支持滚动。直接让Grid成为页签子项，
        % 可同时保持随窗口变宽和按固定RowHeight产生纵向滚动条；额外
        % 套用像素Panel会令隐藏页签中的Grid停留在默认100×100尺寸。

        grid = uigridlayout(parent, gridSize, ...
            'Scrollable', 'on', 'Tag', 'HyperEEGScrollPanel', ...
            'BackgroundColor', colors.background);
    end

    function config = collectConfig()
        config.paths.rawInputDir = string(strtrim(controls.rawInput.Value));
        config.paths.segmentOutputDir = ...
            string(strtrim(controls.segmentOutput.Value));
        config.paths.artifactOutputDir = ...
            string(strtrim(controls.artifactOutput.Value));
        config.paths.cleanOutputDir = ...
            string(strtrim(controls.cleanOutput.Value));
        config.paths.dataIgnorePath = ...
            string(strtrim(controls.ignorePath.Value));
        config.paths.segmentPlanPath = ...
            string(strtrim(controls.segmentPlanPath.Value));
        config.stages.segment.enabled = controls.stageSegment.Value;
        config.stages.artifact.enabled = controls.stageArtifact.Value;
        config.stages.preprocess.enabled = controls.stagePreprocess.Value;
        config.logSwitch = string(controls.logSwitch.Value);

        config.artifactOptions.inputType = ...
            string(controls.artifactInputType.Value);
        config.artifactOptions.auto.enabled = ...
            controls.artifactAutoEnabled.Value;
        config.artifactOptions.manual.enabled = ...
            controls.artifactManualEnabled.Value;
        config.artifactOptions.apply.enabled = ...
            controls.artifactApplyEnabled.Value;
        config.artifactOptions.windowDuration_s = controls.windowDuration.Value;
        config.artifactOptions.windowOverlap = controls.windowOverlap.Value;
        config.artifactOptions.robustZThreshold = ...
            controls.robustZThreshold.Value;
        config.artifactOptions.severeZThreshold = ...
            controls.severeZThreshold.Value;
        config.artifactOptions.minMetricVotes = controls.minMetricVotes.Value;
        config.artifactOptions.minBadChannelRatio = ...
            controls.minBadChannelRatio.Value;
        config.artifactOptions.covarianceZThreshold = ...
            controls.covarianceZThreshold.Value;
        config.artifactOptions.covarianceRegularization = ...
            controls.covarianceRegularization.Value;
        config.artifactOptions.flatScaleRatio = controls.flatScaleRatio.Value;
        config.artifactOptions.mergeGap_s = controls.mergeGap.Value;
        config.artifactOptions.minWindowCount = controls.minWindowCount.Value;

        config.preprocessOptions.inputType = ...
            string(controls.preprocessInputType.Value);
        config.preprocessOptions.resample.enabled = ...
            controls.resampleEnabled.Value;
        config.preprocessOptions.resample.targetRate = controls.targetRate.Value;
        config.preprocessOptions.detrend.enabled = controls.detrendEnabled.Value;
        config.preprocessOptions.detrend.method = ...
            string(controls.detrendMethod.Value);
        config.preprocessOptions.bandpass.enabled = ...
            controls.bandpassEnabled.Value;
        config.preprocessOptions.bandpass.profile = ...
            string(controls.bandpassProfile.Value);
        config.preprocessOptions.bandpass.rangeHz = ...
            parseNumericVector(controls.bandpassRange.Value, true);
        config.preprocessOptions.bandpass.order = controls.bandpassOrder.Value;
        config.preprocessOptions.notch.enabled = controls.notchEnabled.Value;
        config.preprocessOptions.notch.lineFrequencyHz = ...
            controls.lineFrequency.Value;
        config.preprocessOptions.notch.bandwidthHz = ...
            controls.notchBandwidth.Value;
        config.preprocessOptions.notch.order = controls.notchOrder.Value;
        config.preprocessOptions.reference.enabled = ...
            controls.referenceEnabled.Value;
        config.preprocessOptions.reference.method = ...
            string(controls.referenceMethod.Value);
        config.preprocessOptions.reference.channels = ...
            parseNumericVector(controls.referenceChannels.Value, true);
        config.preprocessOptions.artifact.enabled = ...
            controls.preArtifactEnabled.Value;
        config.preprocessOptions.artifact.auto.enabled = ...
            controls.preAutoEnabled.Value;
        methods = strings(0, 1);

        if controls.methodRobust.Value
            methods(end + 1) = "robust";
        end

        if controls.methodASR.Value
            methods(end + 1) = "asr";
        end

        if controls.methodICA.Value
            methods(end + 1) = "ica";
        end

        if isempty(methods)
            methods = "none";
        end

        config.preprocessOptions.artifact.auto.methods = methods(:)';
        config.preprocessOptions.artifact.auto.robustZ = controls.robustZ.Value;
        config.preprocessOptions.artifact.auto.robustWindow_s = ...
            controls.robustWindow.Value;
        config.preprocessOptions.artifact.auto.icaKurtosisZ = ...
            controls.icaKurtosisZ.Value;
        config.preprocessOptions.artifact.auto.icaHighFrequencyZ = ...
            controls.icaHighFrequencyZ.Value;
        config.preprocessOptions.artifact.auto.icaMaxRejectFraction = ...
            controls.icaMaxRejectFraction.Value;
        config.preprocessOptions.artifact.auto.icaRejectComponents = ...
            parseNumericVector(controls.icaRejectComponents.Value, true);
        config.preprocessOptions.artifact.auto.icaMaxTrainingSamples = ...
            controls.autoICAMaxTrainingSamples.Value;
        config.preprocessOptions.artifact.auto.asrBurstCriterion = ...
            controls.asrBurstCriterion.Value;
        config.preprocessOptions.artifact.auto.asrMaxMemoryMB = ...
            controls.asrMaxMemory.Value;
        config.preprocessOptions.artifact.icaManual.enabled = ...
            controls.icaManualEnabled.Value;
        config.preprocessOptions.artifact.icaManual.maxTrainingSamples = ...
            controls.manualICAMaxTrainingSamples.Value;
        config.preprocessOptions.artifact.manual.enabled = ...
            controls.frequencyManualEnabled.Value;
        config = HyperEEG.MultiCH.main.WorkflowOptions(config);
    end

    function values = parseNumericVector(valueText, allowEmpty)
        normalized = regexprep(strtrim(string(valueText)), '[\[\],;]', ' ');

        if strlength(normalized) == 0
            if allowEmpty
                values = [];
                return;
            end

            error("数值向量不能为空。");
        end

        values = sscanf(char(normalized), '%f')';

        if isempty(values) || any(~isfinite(values))
            error("无法解析数值向量：%s", valueText);
        end
    end

    function runOrder(order)
        setRunning(true);
        cleanup = onCleanup(@() setRunning(false)); %#ok<NASGU>
        appendStatus("正在验证配置……");

        try
            config = collectConfig();
            appendStatus("配置有效，开始运行" + order);
            results = HyperEEG.MultiCH.pipeline.Workflow_pipeline( ...
                config, order, @reportProgress);

            if results.completed
                controls.statusLabel.Text = '完成';
                uialert(fig, ...
                    '工作流已完成，请检查各阶段日志和输出目录。', ...
                    'HyperEEG');
            else
                controls.statusLabel.Text = '已安全停止';
                uialert(fig, char(results.status), ...
                    '工作流未继续', 'Icon', 'warning');
            end
        catch ME
            if strcmp(ME.identifier, 'HyperEEG:UserCancelled')
                controls.statusLabel.Text = '任务已取消，界面仍保留';
                appendStatus("任务已按用户请求取消。");
                uialert(fig, '当前任务已停止，界面和参数仍然保留。', ...
                    '任务已取消', 'Icon', 'info');
            else
                controls.statusLabel.Text = '失败：请查看运行日志';
                errorReport = string(getReport( ...
                    ME, 'extended', 'hyperlinks', 'off'));
                appendStatus("错误详情：" + errorReport);
                uialert(fig, ME.message, '运行失败', 'Icon', 'error');
            end
        end
    end

    function setRunning(runningState)
        if ~isvalid(fig)
            return;
        end

        if runningState
            HyperEEG.MultiCH.misc.WorkflowCancel("reset");
            isRunning = true;
            enabled = 'off';
            controls.statusLabel.Text = '运行中，请不要关闭人工复核窗口';
        else
            isRunning = false;
            HyperEEG.MultiCH.misc.WorkflowCancel("reset");
            enabled = 'on';

            if startsWith(controls.statusLabel.Text, '运行中')
                controls.statusLabel.Text = '就绪';
            end
        end

        controls.runSegmentFirst.Enable = enabled;
        controls.runPreprocessFirst.Enable = enabled;
        drawnow;
    end

    function reportProgress(message)
        appendStatus(message);
        HyperEEG.MultiCH.misc.WorkflowCancel("throw");
    end

    function appendStatus(message)
        timestamp = string(datetime('now', 'Format', 'HH:mm:ss'));
        line = "[" + timestamp + "] " + string(message);
        current = string(controls.logArea.Value);

        if numel(current) == 1 && current == "等待运行。"
            current = strings(0, 1);
        end

        controls.logArea.Value = cellstr([current(:); line]);
        controls.logArea.Value = controls.logArea.Value( ...
            max(1, numel(controls.logArea.Value) - 499):end);
        controls.statusLabel.Text = char(message);
        drawnow limitrate;
    end

    function requestClose(~, ~)
        if ~isRunning
            delete(fig);
            return;
        end

        choice = uiconfirm(fig, ...
            ['任务正在进行。是否取消当前任务？', newline, ...
            '确认后会停止处理，但不会关闭本界面。'], ...
            '确认取消任务', ...
            'Options', {'取消任务', '继续运行'}, ...
            'DefaultOption', 2, 'CancelOption', 2, ...
            'Icon', 'warning');

        if strcmp(choice, '取消任务')
            HyperEEG.MultiCH.misc.WorkflowCancel("request");
            controls.statusLabel.Text = '正在取消，请等待当前计算安全退出';
            appendStatus("收到取消请求，正在停止当前任务……");
            closeActiveReviewWindows();
            drawnow;
        end
    end

    function closeActiveReviewWindows()
        tags = ["HyperEEGArtifactEditor", "HyperEEGManualICA", ...
            "HyperEEGFrequencyReview", "HyperEEGMarkerSegmentEditor", ...
            "HyperEEGPlot", "HyperEEGICAProgress"];

        for itag = 1:numel(tags)
            openFigures = findall(groot, 'Type', 'figure', ...
                'Tag', char(tags(itag)));

            for ifigure = 1:numel(openFigures)
                if isgraphics(openFigures(ifigure))
                    close(openFigures(ifigure));
                end
            end
        end
    end

end

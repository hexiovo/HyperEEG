function varargout = HyperEEG(varargin)
%HYPEREEG 打开HyperEEG模式选择器，类似输入eeglab启动EEGLAB。
%   HyperEEG()显示单通道和多通道入口；单通道当前为待开发状态。
%   HyperEEG('Visible','off')用于自动化界面构建检查。

    parser = inputParser;
    addParameter(parser, 'Visible', 'on', ...
        @(value) any(strcmpi(string(value), ["on", "off"])));
    parse(parser, varargin{:});

    colors.primary = [0.118, 0.227, 0.373];
    colors.background = [0.973, 0.980, 0.988];
    colors.surface = [1, 1, 1];
    colors.success = [0.020, 0.588, 0.412];
    colors.muted = [0.392, 0.455, 0.545];

    fig = uifigure('Name', 'HyperEEG', ...
        'Position', [360, 220, 720, 430], ...
        'Color', colors.background, ...
        'Visible', char(parser.Results.Visible));
    root = uigridlayout(fig, [3, 1]);
    root.RowHeight = {88, '1x', 48};
    root.Padding = [18, 16, 18, 16];
    root.RowSpacing = 14;

    header = uipanel(root, 'BorderType', 'none', ...
        'BackgroundColor', colors.primary);
    headerGrid = uigridlayout(header, [2, 1]);
    headerGrid.RowHeight = {42, 26};
    headerGrid.Padding = [20, 9, 20, 7];
    headerGrid.BackgroundColor = colors.primary;
    uilabel(headerGrid, 'Text', 'HyperEEG', ...
        'FontSize', 25, 'FontWeight', 'bold', ...
        'FontColor', [1, 1, 1]);
    uilabel(headerGrid, 'Text', '请选择当前数据采集系统', ...
        'FontSize', 13, 'FontColor', [0.88, 0.93, 0.98]);

    cards = uigridlayout(root, [1, 2]);
    cards.ColumnWidth = {'1x', '1x'};
    cards.ColumnSpacing = 16;
    cards.Padding = [0, 0, 0, 0];

    singlePanel = uipanel(cards, 'Title', '单通道系统', ...
        'FontWeight', 'bold', 'BackgroundColor', colors.surface);
    singleGrid = uigridlayout(singlePanel, [3, 1]);
    singleGrid.RowHeight = {54, '1x', 48};
    singleGrid.Padding = [18, 18, 18, 18];
    uilabel(singleGrid, 'Text', '单通道', 'FontSize', 22, ...
        'FontWeight', 'bold', 'FontColor', colors.muted);
    uilabel(singleGrid, 'Text', ...
        'RDS / IDS 数据整理、转换与处理流程。当前版本尚未开放。', ...
        'WordWrap', 'on', 'FontColor', colors.muted);
    singleButton = uibutton(singleGrid, 'push', ...
        'Text', '待开发', 'Enable', 'off', ...
        'Tag', 'SingleChannelPlaceholder');

    multiPanel = uipanel(cards, 'Title', '多通道系统', ...
        'FontWeight', 'bold', 'BackgroundColor', colors.surface);
    multiGrid = uigridlayout(multiPanel, [3, 1]);
    multiGrid.RowHeight = {54, '1x', 48};
    multiGrid.Padding = [18, 18, 18, 18];
    uilabel(multiGrid, 'Text', '多通道', 'FontSize', 22, ...
        'FontWeight', 'bold', 'FontColor', colors.primary);
    uilabel(multiGrid, 'Text', ...
        '进入BDF Marker、坏段、预处理和后续分析的统一工作流。', ...
        'WordWrap', 'on', 'FontColor', colors.muted);
    multiButton = uibutton(multiGrid, 'push', ...
        'Text', '进入多通道工作流', 'FontWeight', 'bold', ...
        'FontColor', [1, 1, 1], ...
        'BackgroundColor', colors.success, ...
        'Tag', 'OpenMultiChannelWorkflow', ...
        'ButtonPushedFcn', @openMultiChannel);

    footer = uigridlayout(root, [1, 2]);
    footer.ColumnWidth = {'1x', 110};
    footer.Padding = [0, 0, 0, 0];
    uilabel(footer, 'Text', ...
        'MATLAB R2023a · 原始数据只读 · 各阶段结果分目录保存', ...
        'FontColor', colors.muted);
    closeButton = uibutton(footer, 'push', 'Text', '关闭', ...
        'ButtonPushedFcn', @(~, ~) close(fig));

    app.Figure = fig;
    app.Controls.singleChannel = singleButton;
    app.Controls.multiChannel = multiButton;
    app.Controls.close = closeButton;

    if nargout > 1
        error("HyperEEG最多返回一个UI结构体。");
    elseif nargout == 1
        varargout{1} = app;
    else
        printIntroduction();
    end

    function openMultiChannel(~, ~)
        if isvalid(fig)
            close(fig);
        end

        feval('HyperEEG.MultiCH.pipeline.WorkflowUI');
    end

    function printIntroduction()
        fprintf('\n============================================================\n');
        fprintf('名称为：HyperEEG 多人脑电标准处理平台\n');
        fprintf('版本为：V0.5.4\n');
        fprintf('版权为：© 2026 HyperEEG 项目（作者：hexi；维护联系：彭洋）\n');
        fprintf('适用环境为：MATLAB R2023a，EEGLAB + BIOSIG；ASR需clean_rawdata。\n');
        fprintf('注意事项为：\n');
        fprintf('  1. 原始BDF只读，各处理阶段请使用不同输出目录。\n');
        fprintf('  2. 多人连续记录推荐先预处理、后分段，避免重复人工ICA。\n');
        fprintf('  3. 自动坏段、ASR和ICA均需结合人工复核，不作为诊断结论。\n');
        fprintf('  4. 单通道流程当前待开发；多通道流程已开放。\n');
        fprintf('============================================================\n\n');
    end

end

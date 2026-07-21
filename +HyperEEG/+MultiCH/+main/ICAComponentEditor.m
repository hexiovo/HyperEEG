function [rejectComponents, cancelbool] = ICAComponentEditor( ...
        icaModel, timeValues, currentfilename)
%ICACOMPONENTEDITOR 逐个显示ICA成分并收集人工拒绝成分序号。
%   界面同时显示成分时间序列、功率谱和通道混合权重。确认可返回空
%   序号（不删除成分）；关闭窗口或点击取消返回cancelbool=1。

    if nargin < 3 || strlength(string(currentfilename)) == 0
        currentfilename = "当前数据";
    end

    nComponent = icaModel.componentCount;
    timeValues = double(timeValues(:)');

    if numel(timeValues) ~= size(icaModel.activation, 2)
        error("ICA成分采样点数与EEGdata.times不一致。");
    end

    rejectComponents = zeros(1, 0);
    cancelbool = 1;
    fig = figure('Color', 'w', ...
        'Name', "Manual ICA - " + string(currentfilename), ...
        'NumberTitle', 'off', ...
        'Tag', 'HyperEEGManualICA', ...
        'Units', 'normalized', ...
        'Position', [0.08 0.08 0.84 0.82], ...
        'CloseRequestFcn', @cancelEditor);

    timeAxis = axes(fig, 'Units', 'normalized', ...
        'Position', [0.07 0.48 0.58 0.43]);
    spectrumAxis = axes(fig, 'Units', 'normalized', ...
        'Position', [0.70 0.48 0.26 0.43]);
    weightAxis = axes(fig, 'Units', 'normalized', ...
        'Position', [0.07 0.13 0.58 0.24]);

    componentMenu = uicontrol(fig, 'Style', 'popupmenu', ...
        'Units', 'normalized', 'Position', [0.70 0.34 0.26 0.05], ...
        'String', cellstr(compose('IC %d', 1:nComponent)), ...
        'Value', 1, 'Callback', @changeComponent);
    uicontrol(fig, 'Style', 'pushbutton', 'String', '上一个', ...
        'Units', 'normalized', 'Position', [0.70 0.27 0.12 0.05], ...
        'Callback', @(~,~) moveComponent(-1));
    uicontrol(fig, 'Style', 'pushbutton', 'String', '下一个', ...
        'Units', 'normalized', 'Position', [0.84 0.27 0.12 0.05], ...
        'Callback', @(~,~) moveComponent(1));
    rejectToggle = uicontrol(fig, 'Style', 'togglebutton', ...
        'String', '标记当前成分为伪迹', ...
        'Units', 'normalized', 'Position', [0.70 0.19 0.26 0.06], ...
        'Callback', @toggleReject);
    selectedText = uicontrol(fig, 'Style', 'text', ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left', ...
        'Units', 'normalized', 'Position', [0.70 0.11 0.26 0.06]);
    confirmControl = uicontrol(fig, 'Style', 'pushbutton', ...
        'String', '确认ICA选择', 'Enable', 'off', ...
        'Units', 'normalized', 'Position', [0.70 0.03 0.12 0.06], ...
        'Callback', @confirmEditor);
    uicontrol(fig, 'Style', 'pushbutton', 'String', '取消当前文件', ...
        'Units', 'normalized', 'Position', [0.84 0.03 0.12 0.06], ...
        'Callback', @cancelEditor);
    uicontrol(fig, 'Style', 'text', 'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left', 'Units', 'normalized', ...
        'Position', [0.07 0.02 0.58 0.07], ...
        'String', ['仅删除形态明确的眼动、心电、肌电或电极噪声成分；' ...
        '不确定时保留。八通道ICA证据有限，确认空选择也是有效结果。']);

    continuousBlocks = ...
        HyperEEG.MultiCH.core.PreprocessContinuousBlocks(timeValues);
    breakAfterSample = false(1, max(numel(timeValues) - 1, 0));

    if size(continuousBlocks, 1) > 1
        breakAfterSample(continuousBlocks(1:end-1, 2)) = true;
    end

    cumulativeBreak = [0, cumsum(breakAfterSample)];
    refreshComponent();
    confirmControl.Enable = 'on';
    drawnow;
    uiwait(fig);

    function changeComponent(~, ~)
        refreshComponent();
    end

    function moveComponent(step)
        componentMenu.Value = max(1, min(nComponent, ...
            componentMenu.Value + step));
        refreshComponent();
    end

    function toggleReject(~, ~)
        currentComponent = componentMenu.Value;

        if rejectToggle.Value == 1
            rejectComponents = unique([rejectComponents, currentComponent]);
        else
            rejectComponents(rejectComponents == currentComponent) = [];
        end

        updateSelectionText();
    end

    function refreshComponent()
        currentComponent = componentMenu.Value;
        componentData = double(icaModel.activation(currentComponent, :));
        maxDisplayPoint = 10000;
        displayStep = max(1, ceil(numel(timeValues) / maxDisplayPoint));
        displayIndex = 1:displayStep:numel(timeValues);

        if displayIndex(end) ~= numel(timeValues)
            displayIndex(end + 1) = numel(timeValues);
        end

        [displayTimes, displayData] = addGapSeparators( ...
            displayIndex, componentData);
        cla(timeAxis);
        plot(timeAxis, displayTimes, displayData, 'k', 'LineWidth', 0.8);
        grid(timeAxis, 'on');
        xlabel(timeAxis, 'Time（与EEGdata.times单位一致）');
        ylabel(timeAxis, 'Activation');
        title(timeAxis, sprintf( ...
            'IC %d：Kurtosis Z=%.2f，High-frequency Z=%.2f', ...
            currentComponent, icaModel.kurtosisZ(currentComponent), ...
            icaModel.highFrequencyZ(currentComponent)));
        timeAxis.XAxis.Exponent = 0;

        cla(spectrumAxis);
        plotSpectrum(componentData);
        cla(weightAxis);
        bar(weightAxis, icaModel.mixingMatrix(:, currentComponent));
        usableIndex = find(icaModel.usableChannel);
        xticks(weightAxis, 1:numel(usableIndex));
        xticklabels(weightAxis, compose('Ch%d', usableIndex));
        xlabel(weightAxis, 'Channel');
        ylabel(weightAxis, 'Mixing weight');
        title(weightAxis, '成分在各通道上的权重');
        grid(weightAxis, 'on');
        rejectToggle.Value = ismember(currentComponent, rejectComponents);
        updateSelectionText();
        drawnow limitrate;
    end

    function plotSpectrum(componentData)
        if exist('pwelch', 'file') == 2
            windowLength = max(32, round(2 * icaModel.sampleRate));
            windowLength = min(windowLength, numel(componentData));
            [powerValue, frequency] = pwelch(componentData, ...
                windowLength, [], [], icaModel.sampleRate);
        else
            fftLength = min(numel(componentData), 16384);
            spectrumValue = fft(componentData(1:fftLength));
            powerValue = abs(spectrumValue(1:floor(fftLength / 2) + 1)).^2;
            frequency = (0:floor(fftLength / 2))' * ...
                icaModel.sampleRate / fftLength;
        end

        plot(spectrumAxis, frequency, ...
            10 * log10(max(powerValue, eps)), 'b', 'LineWidth', 0.8);
        xlim(spectrumAxis, [0, icaModel.sampleRate / 2]);
        xlabel(spectrumAxis, 'Frequency (Hz)');
        ylabel(spectrumAxis, 'Power (dB)');
        title(spectrumAxis, '功率谱');
        grid(spectrumAxis, 'on');
    end

    function updateSelectionText()
        if isempty(rejectComponents)
            selectedText.String = '当前选择：无（保留全部成分）';
        else
            selectedText.String = ['待删除成分：', ...
                strjoin(string(rejectComponents), ', ')];
        end
    end

    function [plotTimes, plotData] = addGapSeparators( ...
            displayIndex, sourceData)
        if numel(displayIndex) < 2
            plotTimes = timeValues(displayIndex);
            plotData = sourceData(displayIndex);
            return;
        end

        breakBetween = cumulativeBreak(displayIndex(2:end)) > ...
            cumulativeBreak(displayIndex(1:end-1));
        insertBefore = [false, breakBetween];
        sourcePosition = (1:numel(displayIndex)) + cumsum(insertBefore);
        outputLength = numel(displayIndex) + sum(insertBefore);
        plotTimes = nan(1, outputLength);
        plotData = nan(1, outputLength);
        plotTimes(sourcePosition) = timeValues(displayIndex);
        plotData(sourcePosition) = sourceData(displayIndex);
    end

    function confirmEditor(~, ~)
        cancelbool = 0;
        uiresume(fig);
        delete(fig);
    end

    function cancelEditor(~, ~)
        cancelbool = 1;
        rejectComponents = zeros(1, 0);

        if isvalid(fig)
            uiresume(fig);
            delete(fig);
        end
    end

end

function [reviewResult, cancelbool, excludeFileBool] = ...
        FrequencyReviewEditor(EEGdata, currentfilename)
%FREQUENCYREVIEWEDITOR 最终人工复核的通道×频率Hz交互界面。
%   可标记整条坏导、确认整文件无效或确认通过；不收集时间坏段。

    sampleRate = HyperEEG.MultiCH.core.PreprocessSampleRate(EEGdata);
    [frequencyHz, powerDb] = ...
        HyperEEG.MultiCH.core.PreprocessChannelSpectrum( ...
        EEGdata.data, EEGdata.times, sampleRate);
    nChannel = size(EEGdata.data, 1);
    availableChannels = find(~all( ...
        isnan(EEGdata.data) | isinf(EEGdata.data), 2))';

    if isempty(availableChannels)
        error("没有可供频域复核的有效通道。");
    end

    badChannels = zeros(1, 0);
    flaggedBands = zeros(0, 3); % 每行为[channel,startHz,endHz]
    cancelbool = 1;
    excludeFileBool = 0;
    reviewResult = struct();
    frequencyCursor = [];

    fig = figure('Color', 'w', ...
        'Name', "Final Frequency Review - " + string(currentfilename), ...
        'NumberTitle', 'off', 'Tag', 'HyperEEGFrequencyReview', ...
        'Units', 'normalized', 'Position', [0.10 0.08 0.80 0.82], ...
        'CloseRequestFcn', @cancelReview);
    fig.UserData = 'editing';
    heatmapAxis = axes(fig, 'Units', 'normalized', ...
        'Position', [0.08 0.50 0.70 0.42]);
    lineAxis = axes(fig, 'Units', 'normalized', ...
        'Position', [0.08 0.13 0.70 0.26]);
    imagesc(heatmapAxis, frequencyHz, 1:nChannel, powerDb);
    axis(heatmapAxis, 'xy');
    yticks(heatmapAxis, 1:nChannel);
    yticklabels(heatmapAxis, compose('Ch%d', 1:nChannel));
    xlabel(heatmapAxis, 'Frequency (Hz)');
    ylabel(heatmapAxis, 'Channel');
    title(heatmapAxis, '最终人工复核：通道 × 频率PSD');
    heatmapColorbar = colorbar(heatmapAxis);
    heatmapColorbar.Label.String = 'Power (dB/Hz)';
    xlim(heatmapAxis, [0, sampleRate / 2]);

    channelMenu = uicontrol(fig, 'Style', 'popupmenu', ...
        'Units', 'normalized', 'Position', [0.82 0.87 0.15 0.05], ...
        'String', cellstr(compose('Channel %d', availableChannels)), ...
        'Value', 1, 'Callback', @(~,~) refreshChannel());
    uicontrol(fig, 'Style', 'pushbutton', 'String', '上一个', ...
        'Tag', 'PreviousFrequencyChannel', 'Units', 'normalized', ...
        'Position', [0.82 0.81 0.07 0.045], ...
        'Callback', @(~,~) moveChannel(-1));
    uicontrol(fig, 'Style', 'pushbutton', 'String', '下一个', ...
        'Tag', 'NextFrequencyChannel', 'Units', 'normalized', ...
        'Position', [0.90 0.81 0.07 0.045], ...
        'Callback', @(~,~) moveChannel(1));
    badToggle = uicontrol(fig, 'Style', 'togglebutton', ...
        'Units', 'normalized', 'Position', [0.82 0.73 0.15 0.055], ...
        'String', '标记当前通道为坏导', 'Callback', @toggleBadChannel);
    uicontrol(fig, 'Style', 'text', 'String', '起始Hz', ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left', ...
        'Units', 'normalized', 'Position', [0.82 0.665 0.06 0.035]);
    bandStartEdit = uicontrol(fig, 'Style', 'edit', ...
        'Tag', 'FrequencyBandStart', 'Units', 'normalized', ...
        'Position', [0.89 0.665 0.08 0.04]);
    uicontrol(fig, 'Style', 'text', 'String', '结束Hz', ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left', ...
        'Units', 'normalized', 'Position', [0.82 0.615 0.06 0.035]);
    bandEndEdit = uicontrol(fig, 'Style', 'edit', ...
        'Tag', 'FrequencyBandEnd', 'Units', 'normalized', ...
        'Position', [0.89 0.615 0.08 0.04]);
    uicontrol(fig, 'Style', 'pushbutton', ...
        'String', '添加当前通道可疑频段', 'Tag', 'AddFrequencyBand', ...
        'Units', 'normalized', 'Position', [0.82 0.555 0.15 0.045], ...
        'Callback', @addFrequencyBand);
    bandList = uicontrol(fig, 'Style', 'listbox', ...
        'Tag', 'FrequencyBandList', 'Units', 'normalized', ...
        'Position', [0.82 0.405 0.15 0.135], 'String', {'可疑频段：无'});
    uicontrol(fig, 'Style', 'pushbutton', ...
        'String', '删除所选频段', 'Units', 'normalized', ...
        'Position', [0.82 0.355 0.15 0.04], ...
        'Callback', @deleteFrequencyBand);
    selectedText = uicontrol(fig, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.82 0.30 0.15 0.045], ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
    confirmControl = uicontrol(fig, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.82 0.21 0.15 0.06], ...
        'String', '确认频域复核', 'Enable', 'off', ...
        'Callback', @confirmReview);
    uicontrol(fig, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.82 0.13 0.15 0.06], ...
        'String', '整文件无效', 'Callback', @excludeFile);
    uicontrol(fig, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.82 0.05 0.15 0.06], ...
        'String', '取消当前文件', 'Callback', @cancelReview);

    refreshChannel();
    confirmControl.Enable = 'on';
    drawnow;
    waitfor(fig, 'UserData', 'done');

    if isvalid(fig)
        delete(fig);
    end

    function refreshChannel()
        currentChannel = availableChannels(channelMenu.Value);
        cla(lineAxis);
        spectrumLine = plot(lineAxis, frequencyHz, ...
            powerDb(currentChannel, :), ...
            'b', 'LineWidth', 1);
        xlabel(lineAxis, 'Frequency (Hz)');
        ylabel(lineAxis, 'Power (dB/Hz)');
        title(lineAxis, sprintf('Channel %d PSD', currentChannel));
        xlim(lineAxis, [0, sampleRate / 2]);
        grid(lineAxis, 'on');
        frequencyCursor = xline(lineAxis, frequencyHz(1), '--r', ...
            'LineWidth', 1.2, 'Visible', 'off');
        frequencyCursor.HitTest = 'off';
        spectrumLine.ButtonDownFcn = @showFrequencyCoordinate;
        lineAxis.ButtonDownFcn = @showFrequencyCoordinate;
        badToggle.Value = ismember(currentChannel, badChannels);
        updateSelectedText();
    end

    function moveChannel(step)
        channelMenu.Value = max(1, min(numel(availableChannels), ...
            channelMenu.Value + step));
        refreshChannel();
    end

    function toggleBadChannel(~, ~)
        currentChannel = availableChannels(channelMenu.Value);

        if badToggle.Value == 1
            badChannels = unique([badChannels, currentChannel]);
        else
            badChannels(badChannels == currentChannel) = [];
        end

        updateSelectedText();
    end

    function updateSelectedText()
        if isempty(badChannels)
            selectedText.String = '坏导：无';
        else
            selectedText.String = ['坏导：', ...
                strjoin(string(badChannels), ', ')];
        end
    end

    function addFrequencyBand(~, ~)
        startHz = str2double(strtrim(string(bandStartEdit.String)));
        endHz = str2double(strtrim(string(bandEndEdit.String)));

        if ~isfinite(startHz) || ~isfinite(endHz) || ...
                startHz < 0 || endHz <= startHz || ...
                endHz > sampleRate / 2
            errordlg(sprintf( ...
                '频段必须满足 0 <= 起始Hz < 结束Hz <= %.3g。', ...
                sampleRate / 2), '频段输入错误', 'modal');
            return;
        end

        currentBand = [availableChannels(channelMenu.Value), ...
            startHz, endHz];
        duplicateBand = ~isempty(flaggedBands) && any( ...
            flaggedBands(:, 1) == currentBand(1) & ...
            abs(flaggedBands(:, 2) - currentBand(2)) < 1e-9 & ...
            abs(flaggedBands(:, 3) - currentBand(3)) < 1e-9);

        if ~duplicateBand
            flaggedBands(end + 1, :) = currentBand; %#ok<AGROW>
        end

        updateBandList();
        updateBandOverlay();
    end

    function deleteFrequencyBand(~, ~)
        if isempty(flaggedBands)
            return;
        end

        selectedIndex = min(bandList.Value, size(flaggedBands, 1));
        flaggedBands(selectedIndex, :) = [];
        updateBandList();
        updateBandOverlay();
    end

    function updateBandList()
        if isempty(flaggedBands)
            bandList.String = {'可疑频段：无'};
            bandList.Value = 1;
        else
            bandList.String = cellstr(compose( ...
                'Ch%d: %.3g–%.3g Hz（仅标记）', ...
                flaggedBands(:, 1), flaggedBands(:, 2), ...
                flaggedBands(:, 3)));
            bandList.Value = min(bandList.Value, size(flaggedBands, 1));
        end
    end

    function updateBandOverlay()
        delete(findobj(heatmapAxis, 'Tag', 'FrequencyBandFlag'));
        hold(heatmapAxis, 'on');

        for iband = 1:size(flaggedBands, 1)
            rectangle(heatmapAxis, 'Position', [ ...
                flaggedBands(iband, 2), ...
                flaggedBands(iband, 1) - 0.4, ...
                flaggedBands(iband, 3) - flaggedBands(iband, 2), ...
                0.8], 'EdgeColor', 'm', 'LineWidth', 1.5, ...
                'Tag', 'FrequencyBandFlag');
        end

        hold(heatmapAxis, 'off');
    end

    function confirmReview(~, ~)
        if numel(badChannels) == numel(availableChannels)
            answer = questdlg('全部剩余有效通道均被标记，是否排除整文件？', ...
                '确认整文件排除', '排除', '返回检查', '返回检查');

            if ~strcmp(answer, '排除')
                return;
            end

            excludeFileBool = 1;
        end

        finishReview(0);
    end

    function excludeFile(~, ~)
        answer = questdlg('确认将当前文件标记为整文件无效？', ...
            '确认整文件排除', '排除', '返回检查', '返回检查');

        if strcmp(answer, '排除')
            excludeFileBool = 1;
            finishReview(0);
        end
    end

    function cancelReview(~, ~)
        finishReview(1);
    end

    function showFrequencyCoordinate(~, ~)
        % 点击左下PSD曲线或坐标区，显示最近频率点的精确横坐标。
        clickedFrequency = lineAxis.CurrentPoint(1, 1);
        [~, nearestIndex] = min(abs(frequencyHz - clickedFrequency));
        selectedFrequency = frequencyHz(nearestIndex);
        frequencyCursor.Value = selectedFrequency;
        frequencyCursor.Label = sprintf('%.3f Hz', selectedFrequency);
        frequencyCursor.Visible = 'on';
    end

    function finishReview(cancelValue)
        cancelbool = cancelValue;
        reviewResult.channel = (1:nChannel)';
        reviewResult.frequencyHz = frequencyHz(:)';
        reviewResult.powerDb = powerDb;
        reviewResult.badChannels = badChannels;
        reviewResult.flaggedBands = buildBandResult();

        if isvalid(fig)
            fig.UserData = 'done';
        end
    end

    function bandResult = buildBandResult()
        bandResult = struct('channel', {}, 'rangeHz', {}, 'action', {});

        for iband = 1:size(flaggedBands, 1)
            bandResult(iband).channel = flaggedBands(iband, 1);
            bandResult(iband).rangeHz = flaggedBands(iband, 2:3);
            bandResult(iband).action = "flag_only";
        end
    end

end

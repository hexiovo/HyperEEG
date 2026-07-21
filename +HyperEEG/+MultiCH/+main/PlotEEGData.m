function fig = PlotEEGData(EEGdata,nSeg)
%PLOTEEGDATA 分页显示多通道EEG，并支持点击读取横坐标。
%   返回fig供调用者在确认、取消或异常时精确关闭波形窗口。


    if nargin < 2 || isempty(nSeg)
        nSeg = 5;
    end

    %% ------------------------
    % 基础检查
    %% ------------------------
    if ~isstruct(EEGdata)
        error('Input must be a structure.');
    end

    times = EEGdata.times(:);
    data  = double(EEGdata.data);

    [nCh, nP] = size(data);

    if nCh < 1 || nP < 2 || numel(times) ~= nP
        error("EEGdata必须包含至少一个通道、两个采样点，且times长度一致。");
    end

    %% ------------------------
    % 横坐标显示精度
    %% ------------------------
    timeDifference = diff(times);
    timeDifference = timeDifference( ...
        isfinite(timeDifference) & timeDifference > 0);

    if isempty(timeDifference)
        timeDecimal = 0;
    else
        timeStep = median(timeDifference);
        timeDecimal = max(0, min(3, ceil(-log10(timeStep))));
    end

    timeFormat = sprintf('%%.%df', timeDecimal);

    %% ------------------------
    % 临时填补NaN/Inf后去均值，仅用于绘图，不修改EEGdata。
    %% ------------------------
    data = HyperEEG.MultiCH.core.PreprocessFillMissing(data);
    data = data - mean(data,2);

    %% ------------------------
    % 泳道间距
    %% ------------------------
    pp = max(data,[],2) - min(data,[],2);
    validPeakToPeak = pp(isfinite(pp) & pp > 0);

    if isempty(validPeakToPeak)
        offset = 1;
    else
        offset = median(validPeakToPeak) * 1.5;
    end

    Y = data + (0:nCh-1)' * offset;

    % 记录时间轴断点。后续即使为了显示而抽点，也能判断两点之间是否
    % 跨过已删除区间，并插入NaN阻止plot把断点两侧连接起来。
    continuousBlocks = ...
        HyperEEG.MultiCH.core.PreprocessContinuousBlocks(times);
    breakAfterSample = false(1, max(nP - 1, 0));

    if size(continuousBlocks, 1) > 1
        breakAfterSample(continuousBlocks(1:end-1, 2)) = true;
    end

    cumulativeBreak = [0, cumsum(breakAfterSample)];

    %% ------------------------
    % 时间窗口设置（关键）
    %% ------------------------

    segLen = floor(nP / nSeg);
    if segLen < 10
        segLen = nP;
    end

    startIdx = 1;
    currentStartIdx = startIdx;
    currentEndIdx = startIdx + segLen - 1;
    maxDisplayPoint = 10000;

    %% ------------------------
    % Figure
    %% ------------------------
    fig = figure(...
    'Color','w',...
    'Name','EEG Viewer',...
    'Tag','HyperEEGPlot',...
    'CloseRequestFcn',@closeFigure);

    function closeFigure(src,~)
        % 停止刷新计时器后再关闭窗口，避免残留回调访问已删除图形。

        delete(src);

    end


    ax = axes(fig);
    hold(ax,'on');

    initialDisplayStep = max(1, ceil(segLen / maxDisplayPoint));
    initialDisplayIdx = startIdx:initialDisplayStep:currentEndIdx;

    if initialDisplayIdx(end) ~= currentEndIdx
        initialDisplayIdx(end + 1) = currentEndIdx;
    end

    [initialTimes, initialData] = ...
        addGapSeparators(initialDisplayIdx, Y);
    hPlot = plot(ax, initialTimes, ...
                      initialData', ...
                      'LineWidth',0.8);

    grid(ax,'on');
    box(ax,'on');

    xlabel(ax,'Time（点击图中查看横坐标）');
    ylabel(ax,'Channel');

    % 关闭1.6×10^6形式的科学计数法
    ax.XAxis.Exponent = 0;

    % offset始终为有限正数，因此yticks严格递增，不受坏导NaN影响。
    yticks(ax,(0:nCh-1)*offset);
    yticklabels(ax,compose('Ch%d',1:nCh));

    coordinateLine = xline(ax, times(startIdx), '--r', ...
        'LineWidth', 1.2, ...
        'Visible', 'off');
    coordinateLine.HitTest = 'off';
    ax.ButtonDownFcn = @showCoordinate;

    for ichannel = 1:numel(hPlot)
        hPlot(ichannel).ButtonDownFcn = @showCoordinate;
    end

    minVal = 1;
    maxVal = max(1, nP - segLen + 1);
    sliderRange = max(maxVal - minVal, 1);
    smallSliderStep = min(1, 1 / sliderRange);
    largeSliderStep = min(1, max(smallSliderStep, 0.1));

    ylim(ax,[-offset*0.5,(nCh-0.5)*offset]);

    %% ------------------------
    % 更新函数（核心）
    %% ------------------------
        function updatePlot(idx)
            % 根据窗口索引重绘曲线，并保持坐标、游标和标题同步。
            idx = round(idx);
            idx = max(1, min(idx, nP-segLen+1));
            endIdx = idx + segLen - 1;
            displayStep = max(1, ceil(segLen / maxDisplayPoint));
            displayIdx = idx:displayStep:endIdx;

            if displayIdx(end) ~= endIdx
                displayIdx(end + 1) = endIdx;
            end

            currentStartIdx = idx;
            currentEndIdx = endIdx;

            [displayTimes, displayData] = ...
                addGapSeparators(displayIdx, Y);

            for i = 1:nCh
                set(hPlot(i), ...
                    'XData', displayTimes, ...
                    'YData', displayData(i, :));
            end

            % 固定显示更多完整数值刻度，避免自动转为科学计数法
            tickValues = linspace(times(idx), times(endIdx), 9);
            xticks(ax, tickValues);
            xticklabels(ax, compose(timeFormat, tickValues));
            xlim(ax, [times(idx), times(endIdx)]);
            coordinateLine.Visible = 'off';
            drawnow limitrate;
        end

    %% ------------------------
    % Slider（左右滑动）
    %% ------------------------
    sliderControl = uicontrol(fig,...
        'Style','slider',...
        'Units','normalized',...
        'Position',[0.1 0.02 0.6 0.04],...
        'Min',1,...
        'Max',nP-segLen+1,...
        'Value',1,...
        'SliderStep',[smallSliderStep largeSliderStep],...
        'Callback',@(src,~) updatePlot(round(src.Value)));

    %% ------------------------
    % 左右按钮
    %% ------------------------
    uicontrol(fig,'Style','pushbutton',...
        'String','<<',...
        'Units','normalized',...
        'Position',[0.72 0.02 0.08 0.04],...
        'Callback',@(~,~) move(-segLen/2));

    uicontrol(fig,'Style','pushbutton',...
        'String','>>',...
        'Units','normalized',...
        'Position',[0.82 0.02 0.08 0.04],...
        'Callback',@(~,~) move(segLen/2));

        function move(step)
            % 左右移动一个显示窗口，边界处保持在有效索引范围内。
            cur = round(sliderControl.Value);
            new = round(cur + step);
            new = max(min(new, maxVal), minVal);
            sliderControl.Value = new;
            updatePlot(new);
        end

    %% ------------------------
    % 初始化
    %% ------------------------
    updatePlot(1);

        function showCoordinate(~, ~)
            % 点击坐标区时显示最接近的原始时间值，便于填写坏段边界。
            currentPoint = ax.CurrentPoint;
            clickedTime = currentPoint(1, 1);
            visibleTimes = times(currentStartIdx:currentEndIdx);
            [~, nearestIndex] = min(abs(visibleTimes - clickedTime));
            selectedTime = visibleTimes(nearestIndex);

            coordinateLine.Value = selectedTime;
            coordinateLine.Label = [ ...
                'Time: ', sprintf(timeFormat, selectedTime)];
            coordinateLine.Visible = 'on';
        end

        function [plotTimes, plotData] = addGapSeparators( ...
                displayIndex, sourceData)
            % 在跨越时间断点的相邻显示点之间插入NaN，保留真实空白距离。

            displayIndex = displayIndex(:)';

            if numel(displayIndex) < 2
                plotTimes = times(displayIndex)';
                plotData = sourceData(:, displayIndex);
                return;
            end

            breakBetween = cumulativeBreak(displayIndex(2:end)) > ...
                cumulativeBreak(displayIndex(1:end-1));
            insertBefore = [false, breakBetween];
            sourcePosition = (1:numel(displayIndex)) + ...
                cumsum(insertBefore);
            outputLength = numel(displayIndex) + sum(insertBefore);
            plotTimes = nan(1, outputLength);
            plotData = nan(nCh, outputLength);
            plotTimes(sourcePosition) = times(displayIndex);
            plotData(:, sourcePosition) = sourceData(:, displayIndex);
        end

end

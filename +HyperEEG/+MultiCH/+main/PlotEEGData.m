function PlotEEGData(EEGdata,nSeg)
    

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
    
    %% ------------------------
    % 去均值
    %% ------------------------
    data = data - mean(data,2);
    
    %% ------------------------
    % 泳道间距
    %% ------------------------
    pp = max(data,[],2) - min(data,[],2);
    offset = median(pp) * 1.5;
    if offset == 0
        offset = 1;
    end
    
    Y = data + (0:nCh-1)' * offset;
    
    %% ------------------------
    % 时间窗口设置（关键）
    %% ------------------------
    
    segLen = floor(nP / nSeg);
    if segLen < 10
        segLen = nP;
        nSeg = 1;
    end
    
    startIdx = 1;
    
    %% ------------------------
    % Figure
    %% ------------------------
    fig = figure(...
    'Color','w',...
    'Name','EEG Viewer',...
    'Tag','HyperEEGPlot',...
    'CloseRequestFcn',@closeFigure);

    function closeFigure(src,~)

        delete(src);
    
    end


    ax = axes(fig);
    hold(ax,'on');
    
    hPlot = plot(ax, times(startIdx:startIdx+segLen-1), ...
                      Y(:,startIdx:startIdx+segLen-1)', ...
                      'LineWidth',0.8);
    
    grid(ax,'on');
    box(ax,'on');
    
    xlabel(ax,'Time');
    ylabel(ax,'Channel');
    
    yticks(ax,(0:nCh-1)*offset);
    yticklabels(ax,compose('Ch%d',1:nCh));

    minVal = 1;
    maxVal = max(1, nP - segLen + 1);
    
    ylim(ax,[-offset*0.5,(nCh-0.5)*offset]);
    
    %% ------------------------
    % 更新函数（核心）
    %% ------------------------
        function updatePlot(idx)
            idx = max(1, min(idx, nP-segLen+1));
    
            for i = 1:nCh
                set(hPlot(i), ...
                    'XData', times(idx:idx+segLen-1), ...
                    'YData', Y(i,idx:idx+segLen-1));
            end
        end
    
    %% ------------------------
    % Slider（左右滑动）
    %% ------------------------
    uicontrol(fig,...
        'Style','slider',...
        'Units','normalized',...
        'Position',[0.1 0.02 0.6 0.04],...
        'Min',1,...
        'Max',nP-segLen+1,...
        'Value',1,...
        'SliderStep',[1/(nP-segLen+1) 0.1],...
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
            cur = round(get(findobj(fig,'Style','slider'),'Value'));
            new = cur + step;
            new = max(min(new, maxVal), minVal);
            set(findobj(fig,'Style','slider'),'Value',new);
            updatePlot(new);
        end
    
    %% ------------------------
    % 初始化
    %% ------------------------
    updatePlot(1);
    
    zoom on;
    pan on;

end
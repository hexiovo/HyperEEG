function [outsegment, emptybool] = SegmentEditor(EEGdata,currentfilename,nSeg)

    if nargin < 3 || isempty(nSeg)
        nSeg = 5;
    end
    
    outsegment = [];
    emptybool = 0;
    
    %%==========================================================
    % 主窗口
    %%==========================================================
    
    fig = uifigure( ...
        'Name',char(currentfilename+"  Segment Editor"), ...
        'Position',[300 100 760 500], ...
        'CloseRequestFcn',@(~,~)safeExit(1));
    
    %%==========================================================
    % 打开EEG窗口
    %%==========================================================
    
    HyperEEG.MultiCH.main.PlotEEGData(EEGdata,nSeg);
    
    %%==========================================================
    % Timer：检查EEG窗口是否存在
    %%==========================================================
    
    plotTimer = timer( ...
        'ExecutionMode','fixedSpacing', ...
        'Period',0.2, ...
        'BusyMode','drop', ...
        'TimerFcn',@checkPlot);
    
    start(plotTimer);
    
    mainLayout = uigridlayout(fig,[2 1]);
    mainLayout.RowHeight = {'1x',40};
    
    %% =========================
    % Segment Panel
    %% =========================
    
    segPanel = uipanel(mainLayout,'Title','Segments');
    
    segLayoutOuter = uigridlayout(segPanel,[2 1]);
    segLayoutOuter.RowHeight = {40,'1x'};
    
    btnAdd = uibutton(segLayoutOuter, ...
        'Text','+ Add Segment');
    
    scrollPanel = uipanel(segLayoutOuter);
    scrollPanel.Scrollable = 'on';
    
    contentPanel = uipanel(scrollPanel);
    contentPanel.Position = [0 0 720 2000];
    
    segLayout = uigridlayout(contentPanel);
    segLayout.ColumnWidth = {250,220,220};
    segLayout.RowHeight = {};
    segLayout.Padding = [5 5 5 5];
    
    segData = {};
    segRow = 0;
    
    %% =========================
    % Add Segment Callback
    %% =========================
    
    btnAdd.ButtonPushedFcn = @addSegment;
    
        function addSegment(~,~)
    
            segRow = segRow + 1;
            r = segRow;
    
            segLayout.RowHeight = [segLayout.RowHeight,{30}];
    
            nameBox = uieditfield(segLayout,'text', ...
                'Placeholder','Name');
    
            startBox = uieditfield(segLayout,'text', ...
                'Placeholder','Start');
    
            endBox = uieditfield(segLayout,'text', ...
                'Placeholder','End');
    
            nameBox.Layout.Row = r;
            nameBox.Layout.Column = 1;
    
            startBox.Layout.Row = r;
            startBox.Layout.Column = 2;
    
            endBox.Layout.Row = r;
            endBox.Layout.Column = 3;
    
            segData{end+1} = struct( ...
                'name',nameBox, ...
                'start',startBox, ...
                'end',endBox);
    
            drawnow;
            contentPanel.Position(4) = contentPanel.Position(4) + 35;
    
        end
    
    %% =========================
    % Bottom Buttons
    %% =========================
    
    btnPanel = uipanel(mainLayout);
    btnLayout = uigridlayout(btnPanel,[1 2]);
    
    btnOK = uibutton(btnLayout,'Text','Confirm');
    btnCancel = uibutton(btnLayout,'Text','Cancel');
    
    btnOK.ButtonPushedFcn = @confirmFcn;
    btnCancel.ButtonPushedFcn = @cancelFcn;
    
    %% =========================
    % Confirm
    %% =========================
    
    function confirmFcn(~,~)
    
        outsegment = struct('name',{},'start',{},'end',{});
    
        for i = 1:length(segData)
    
            nameVal  = strtrim(segData{i}.name.Value);
            startVal = strtrim(segData{i}.start.Value);
            endVal   = strtrim(segData{i}.end.Value);
    
            %% 完全空行跳过
            if isempty(nameVal) && isempty(startVal) && isempty(endVal)
                continue;
            end
    
            %% 只有 name → 默认区间
            if ~isempty(nameVal) && isempty(startVal) && isempty(endVal)
    
                startNum = 0;
                endNum   = 9999999;
    
            else
    
                %% 不完整输入
                if isempty(nameVal) || isempty(startVal) || isempty(endVal)
    
                    uialert(fig, ...
                        sprintf('第 %d 行信息未填写完整', i), ...
                        'Input Error');
                    return;
                end
    
                startNum = str2double(startVal);
    
                if isnan(startNum)
                    uialert(fig, ...
                        sprintf('第 %d 行 Start 非数字', i), ...
                        'Input Error');
                    return;
                end
    
                if strcmpi(endVal,'end')
                    endNum = 9999999;
                else
                    endNum = str2double(endVal);
    
                    if isnan(endNum)
                        uialert(fig, ...
                            sprintf('第 %d 行 End 非数字', i), ...
                            'Input Error');
                        return;
                    end
                end
    
                if endNum <= startNum
                    uialert(fig, ...
                        sprintf('第 %d 行 End 必须大于 Start', i), ...
                        'Input Error');
                    return;
                end
            end
    
            outsegment(end+1) = struct( ...
                'name',nameVal, ...
                'start',startNum, ...
                'end',endNum);
    
        end
    
        safeExit(0);
    
    end
    
    %% =========================
    % Cancel
    %% =========================
    
    function cancelFcn(~,~)
        emptybool = 1;
        safeExit(1);
    end
    
    %% =========================
    % 统一退出
    %% =========================
    
    function safeExit(isCancel)

        %========================
        % stop timer first
        %========================
        if exist('plotTimer','var') && isvalid(plotTimer)
            stop(plotTimer);
            delete(plotTimer);
        end
    
        %========================
        % close EEG window
        %========================
        h = findall(groot,'Type','figure','Tag','HyperEEGPlot');
        if ~isempty(h)
            delete(h);
        end
    
        %========================
        % return value
        %========================
        if isCancel
            emptybool = 1;
            outsegment = [];
        end
    
        %========================
        % release UI wait safely
        %========================
        if isvalid(fig)
            uiresume(fig);
            delete(fig);
        end
    
    end
    
    %%==========================================================
    % Timer检测Plot窗口
    %%==========================================================
    
    function checkPlot(~,~)
    
        % Segment窗口不存在
        if ~isvalid(fig)
            return;
        end
    
        h = findall(groot,...
            'Type','figure',...
            'Tag','HyperEEGPlot');
    
        if isempty(h)
    
            HyperEEG.MultiCH.main.PlotEEGData(EEGdata,nSeg);
    
        end
    
    end
    
    %%==========================================================
    % 停止Timer
    %%==========================================================
    
    function stopTimer()
    
        if exist('plotTimer','var')
    
            if isvalid(plotTimer)
    
                stop(plotTimer);
    
                delete(plotTimer);
    
            end
    
        end
    
    end
    
    %%==========================================================
    % 关闭EEG窗口
    %%==========================================================
    
    function closePlot()
    
        h = findall(groot,...
            'Type','figure',...
            'Tag','HyperEEGPlot');
    
        if ~isempty(h)
    
            delete(h);
    
        end
    
    end
    
    %%==========================================================
    % 等待Segment关闭
    %%==========================================================
    
    uiwait(fig);

end
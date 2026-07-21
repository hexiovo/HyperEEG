function [outmarker , emptybool] = MarkerSegmentEditor(markerdata,currentfilename)
%MARKERSEGMENTEDITOR 显示Marker并收集实验片段名称与边界。
%   markerdata包含type和latency；End可填写数字或end。关闭/取消通过
%   emptybool与正常确认区分。输入边界必须与后续EEG.times单位一致。
    
    
    outmarker = [];
    emptybool = 0;
    
    %% =========================
    % 1. 主窗口
    %% =========================
    titletxt = char(currentfilename+'  mark剪辑窗口');
    fig = uifigure('Name',titletxt, ...
        'Position',[300 100 800 600]);

    mainLayout = uigridlayout(fig,[3 1]);
    mainLayout.RowHeight = {'2x','3x',40};
    
    %% =========================
    % 2. 上方：marker显示（可滚动）
    %% =========================
    topPanel = uipanel(mainLayout,'Title','Markers');
    topScroll = uigridlayout(topPanel,[1 1]);
    
    txt = "";
    for i = 1:length(markerdata.type)
        txt = txt + sprintf('%s\t%d\n', ...
            string(markerdata.type{i}), markerdata.latency{i});
    end
    
    ta = uitextarea(topScroll, ...
        'Value', cellstr(txt), ...
        'Editable','off');
    
    %% =========================
    % 3. 下方：分段编辑区（修正版）
    %% =========================
    
    bottomPanel = uipanel(mainLayout,'Title','Segments');
    
    bottomLayout = uigridlayout(bottomPanel,[2 1]);
    bottomLayout.RowHeight = {40,'1x'};
    
    % ===== 添加按钮 =====
    btnAdd = uibutton(bottomLayout,'Text','+ Add Segment');
    
   segScrollPanel = uipanel(bottomLayout);
    segScrollPanel.Scrollable = 'on';
    
    % ⭐ 新增：内容容器（关键）
    contentPanel = uipanel(segScrollPanel);
    contentPanel.Position = [0 0 740 2000]; % 给一个"足够大"的初始值
    
    segLayout = uigridlayout(contentPanel);
    segLayout.ColumnWidth = {250, 230, 230};
    segLayout.RowHeight = {};
    segLayout.Padding = [5 5 5 5];
    
    
    % ===== 数据存储 =====
    segData = {};
    
    % ===== 行计数器（关键）=====
    segRow = 0;
    
    %% =========================
    % 4. 添加分段函数（修正版）
    %% =========================
    
    function addSegment(~,~)
        % 动态增加一行Name、Start、End输入控件。

        segRow = segRow + 1;
        r = segRow;
    
        % ===== 关键修复：真正扩展 RowHeight =====
        segLayout.RowHeight = [segLayout.RowHeight, {30}];
    
        nameBox  = uieditfield(segLayout,'text','Placeholder','Name');
        startBox = uieditfield(segLayout,'text','Placeholder','Start(数字)');
        endBox   = uieditfield(segLayout,'text','Placeholder','End(数字或END)');
    
        nameBox.Layout.Row = r;
        nameBox.Layout.Column = 1;
    
        startBox.Layout.Row = r;
        startBox.Layout.Column = 2;
    
        endBox.Layout.Row = r;
        endBox.Layout.Column = 3;
    
        segData{end+1} = struct( ...
            'name', nameBox, ...
            'start', startBox, ...
            'end', endBox);
    
        drawnow;
        pause(0.01);
        contentPanel.Position(4) = contentPanel.Position(4) + 35;
    end
    
    btnAdd.ButtonPushedFcn = @addSegment;
    
    %% =========================
    % 5. 底部按钮
    %% =========================
    btnPanel = uipanel(mainLayout);
    btnLayout = uigridlayout(btnPanel,[1 2]);
    
    btnOK = uibutton(btnLayout,'Text','Confirm');
    btnCancel = uibutton(btnLayout,'Text','Cancel');
    
    %% =========================
    % 6. 回调：Cancel
    %% =========================
    btnCancel.ButtonPushedFcn = @(~,~) closeAndReturn([]);
    
    %% =========================
    % 7. 回调：Confirm
    %% =========================
    btnOK.ButtonPushedFcn = @(~,~) collectAndReturn();
    
    %% =========================
    % 8. 收集数据
    %% =========================
        function collectAndReturn()
            % 验证每行完整性和边界顺序，再生成标准分段结构。

            segs = struct('name',{},'start',{},'end',{});
        
            for i = 1:length(segData)
        
                nameVal  = strtrim(segData{i}.name.Value);
                startVal = strtrim(segData{i}.start.Value);
                endVal   = strtrim(segData{i}.end.Value);
        
                % ==============================
                % 1. 完全空行 → 跳过
                % ==============================
                if isempty(nameVal) && isempty(startVal) && isempty(endVal)
                    continue;
                end
        
                % ==============================
                % 2. 部分空 → 阻止
                % ==============================
                if isempty(nameVal) || isempty(startVal) || isempty(endVal)
        
                    uialert(fig, ...
                        sprintf('第 %d 行存在空白字段，请补全后再提交。', i), ...
                        '输入错误');
                    return;
                end
        
                % ==============================
                % 3. start 必须为数字
                % ==============================
                startNum = str2double(startVal);
        
                if isnan(startNum)
        
                    uialert(fig, ...
                        sprintf('第 %d 行 Start 不是有效数字。', i), ...
                        '输入错误');
                    return;
                end
        
                % ==============================
                % 4. end 必须是数字 或 "end"
                % ==============================
                if strcmpi(endVal, 'end')
                    endNum = inf;
                else
                    endNum = str2double(endVal);
        
                    if isnan(endNum)
                        uialert(fig, ...
                            sprintf('第 %d 行 End 不是数字或 "end"。', i), ...
                            '输入错误');
                        return;
                    end
                end
        
                % ==============================
                % 5. 逻辑校验：end > start
                % ==============================
                if endNum <= startNum
        
                    uialert(fig, ...
                        sprintf('第 %d 行 End 必须大于 Start。', i), ...
                        '输入错误');
                    return;
                end
        
                % ==============================
                % 6. 写入结构体
                % ==============================
                segs(end+1) = struct( ...
                    'name', nameVal, ...
                    'start', startNum, ...
                    'end', endNum);
        
            end
        
            outmarker = segs;
        
            close(fig);
        end
    
    %% =========================
    % 9. Cancel函数
    %% =========================
        function closeAndReturn(val)
            % 统一返回确认结果或取消状态，并释放UI窗口。
            outmarker = val;
            emptybool = 1;
            close(fig);
        end
    
    %% 等待窗口关闭
    uiwait(fig);

end

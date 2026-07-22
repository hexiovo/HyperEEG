function [outmarker , emptybool] = MarkerSegmentEditor(markerdata,currentfilename)
%MARKERSEGMENTEDITOR 显示Marker并收集实验片段名称与边界。
%   markerdata包含type、sample_index和time_ms；Start/End统一填写time_ms，
%   End也可填写end。关闭/取消通过emptybool与正常确认区分。


    outmarker = [];
    emptybool = 0;
    
    %% =========================
    % 1. 主窗口
    %% =========================
    titletxt = char(currentfilename+'  mark剪辑窗口');
    fig = uifigure('Name',titletxt, ...
        'Position',[300 100 800 600], ...
        'Tag', 'HyperEEGMarkerSegmentEditor', ...
        'CloseRequestFcn', @(~, ~) closeAndReturn([]));

    mainLayout = uigridlayout(fig,[3 1]);
    mainLayout.RowHeight = {'2x','3x',40};
    
    %% =========================
    % 2. 上方：marker显示（可滚动）
    %% =========================
    topPanel = uipanel(mainLayout,'Title','Markers');
    topScroll = uigridlayout(topPanel,[2 1]);
    topScroll.RowHeight = {24, '1x'};

    uilabel(topScroll, ...
        'Text', 'Sample index 与 Time (ms) 均完整显示；Time (ms) 四舍五入为整数。', ...
        'FontWeight', 'bold');

    % uitable在列宽较窄时可能再次以科学计数法渲染数值，因此这里把三列
    % 预先格式化为纯文本。Consolas仅用于视觉对齐，不改变下游保存的值。
    txt = string(sprintf('Type\tSample index\tTime (ms)\n'));
    for imarker = 1:length(markerdata.type)
        % %.0f保证完整十进制整数且不出现e+06；显示层按需求四舍五入，
        % 原始双精度time_ms仍保留在markerdata中供后续边界换算使用。
        txt = txt + sprintf('%s\t%.0f\t%.0f\n', ...
            string(markerdata.type{imarker}), ...
            markerdata.sample_index{imarker}, ...
            markerdata.time_ms{imarker});
    end

    uitextarea(topScroll, ...
        'Value', cellstr(txt), ...
        'Editable','off', ...
        'FontName', 'Consolas');
    
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
    
    % 滚动面板本身不会随动态控件扩展，因此使用独立内容容器承载输入行。
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
    
        % 每添加一行必须同步扩展RowHeight，否则控件会落在同一网格行并重叠。
        segLayout.RowHeight = [segLayout.RowHeight, {30}];
    
        nameBox  = uieditfield(segLayout,'text','Placeholder','Name');
        startBox = uieditfield(segLayout,'text','Placeholder','Start (time_ms)');
        endBox   = uieditfield(segLayout,'text','Placeholder','End (time_ms或END)');
    
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
        
            for isegment = 1:length(segData)

                nameVal  = strtrim(segData{isegment}.name.Value);
                startVal = strtrim(segData{isegment}.start.Value);
                endVal   = strtrim(segData{isegment}.end.Value);
        
                % ==============================
                % 1. 完全空行 → 跳过
                % 预留空行用于继续添加分段，不能误判为取消或格式错误。
                % ==============================
                if isempty(nameVal) && isempty(startVal) && isempty(endVal)
                    continue;
                end
        
                % ==============================
                % 2. 部分空 → 阻止
                % 名称、起点和终点共同组成一条原子记录，不静默补默认值。
                % ==============================
                if isempty(nameVal) || isempty(startVal) || isempty(endVal)
        
                    uialert(fig, ...
                        sprintf('第 %d 行存在空白字段，请补全后再提交。', isegment), ...
                        '输入错误');
                    return;
                end
        
                % ==============================
                % 3. start 必须为数字
                % UI约定统一为time_ms，避免把sample_index直接混入同一比较。
                % ==============================
                startNum = str2double(startVal);
        
                if isnan(startNum)
        
                    uialert(fig, ...
                        sprintf('第 %d 行 Start 不是有效数字。', isegment), ...
                        '输入错误');
                    return;
                end
        
                % ==============================
                % 4. end 必须是数字 或 "end"
                % inf只是内部哨兵，下游会依据当前文件真实末尾完成裁剪。
                % ==============================
                if strcmpi(endVal, 'end')
                    endNum = inf;
                else
                    endNum = str2double(endVal);
        
                    if isnan(endNum)
                        uialert(fig, ...
                            sprintf('第 %d 行 End 不是数字或 "end"。', isegment), ...
                            '输入错误');
                        return;
                    end
                end
        
                % ==============================
                % 5. 逻辑校验：end > start
                % 严格大于可同时排除零长度片段和方向颠倒的输入。
                % ==============================
                if endNum <= startNum
        
                    uialert(fig, ...
                        sprintf('第 %d 行 End 必须大于 Start。', isegment), ...
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
        
            delete(fig);
        end
    
    %% =========================
    % 9. Cancel函数
    %% =========================
        function closeAndReturn(val)
            % 统一返回确认结果或取消状态，并释放UI窗口。
            outmarker = val;
            emptybool = 1;
            if isvalid(fig)
                delete(fig);
            end
        end
    
    %% 等待窗口关闭
    uiwait(fig);

end

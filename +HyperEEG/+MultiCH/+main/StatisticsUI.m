function app = StatisticsUI(varargin)
%STATISTICSUI HyperEEG统计分析独立控制台。
%   实现5.1时域、5.2频谱/频带及5.3熵/非线性，每项均可独立点选。

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
    controls = struct();
    isRunning = false;

    fig = uifigure('Name', 'HyperEEG Statistics', ...
        'Position', [110, 70, 1240, 840], ...
        'Color', colors.background, 'Visible', visible, ...
        'CloseRequestFcn', @closeWindow);
    root = uigridlayout(fig, [3, 1]);
    root.RowHeight = {68, '1x', 72};
    root.Padding = [16, 12, 16, 12];
    root.RowSpacing = 10;

    header = uipanel(root, 'BorderType', 'none', ...
        'BackgroundColor', colors.primary);
    headerGrid = uigridlayout(header, [2, 1]);
    headerGrid.RowHeight = {31, 22};
    headerGrid.Padding = [18, 7, 18, 5];
    headerGrid.BackgroundColor = colors.primary;
    uilabel(headerGrid, 'Text', 'HyperEEG 统计分析控制台', ...
        'FontSize', 20, 'FontWeight', 'bold', 'FontColor', [1, 1, 1]);
    uilabel(headerGrid, ...
        'Text', '个体水平 · 时域（5.1）· 频谱与频带（5.2）· 熵与非线性（5.3）', ...
        'FontSize', 12, 'FontColor', [0.88, 0.93, 0.98]);

    mainTabs = uitabgroup(root);
    setupTab = uitab(mainTabs, 'Title', '输入与总体控制');
    individualTab = uitab(mainTabs, 'Title', '个体水平：时域统计');
    frequencyTab = uitab(mainTabs, 'Title', '个体水平：频谱与频带');
    nonlinearTab = uitab(mainTabs, 'Title', '个体水平：熵与非线性');
    logTab = uitab(mainTabs, 'Title', '运行日志');
    buildSetupTab();
    buildIndividualTab();
    buildFrequencyTab();
    buildNonlinearTab();
    buildLogTab();
    updateExcelControls();

    footer = uipanel(root, 'BorderType', 'line', ...
        'BackgroundColor', colors.surface);
    footerGrid = uigridlayout(footer, [1, 5]);
    footerGrid.ColumnWidth = {'1x', 150, 170, 170, 100};
    footerGrid.Padding = [14, 9, 14, 9];
    controls.status = uilabel(footerGrid, ...
        'Text', '就绪：请选择clean_data和存储路径', ...
        'FontColor', colors.muted);
    controls.openGuide = uibutton(footerGrid, 'push', ...
        'Text', '打开指标说明', 'Tag', 'OpenStatisticsGuide', ...
        'ButtonPushedFcn', @openStatisticsGuide);
    controls.openExample = uibutton(footerGrid, 'push', ...
        'Text', '打开分组示例目录', 'Tag', 'OpenStatisticsExample', ...
        'ButtonPushedFcn', @openExampleFolder);
    controls.run = uibutton(footerGrid, 'push', ...
        'Text', '开始统计并导出', 'Tag', 'RunStatistics', ...
        'FontWeight', 'bold', 'FontColor', [1, 1, 1], ...
        'BackgroundColor', colors.success, 'ButtonPushedFcn', @runStatistics);
    controls.close = uibutton(footerGrid, 'push', ...
        'Text', '关闭', 'ButtonPushedFcn', @closeWindow);

    app.Figure = fig;
    app.Controls = controls;
    app.getOptions = @collectOptions;
    drawnow;

    function buildSetupTab()
        grid = uigridlayout(setupTab, [15, 4], 'Scrollable', 'on', ...
            'BackgroundColor', colors.background, 'Tag', 'StatisticsSetupScroll');
        grid.RowHeight = [repmat({42}, 1, 12), {78, 78, '1x'}];
        grid.ColumnWidth = {210, '1x', 88, 280};
        grid.Padding = [18, 16, 18, 16];
        grid.RowSpacing = 9;
        controls.inputDir = addPathRow(grid, 1, 'clean_data路径 *', true, ...
            '递归读取MAT；每个文件应包含EEGdata.data');
        controls.outputDir = addPathRow(grid, 2, '统计存储路径 *', true, ...
            '保存每文件MAT及汇总统计XLSX');
        controls.groupFile = addPathRow(grid, 3, '分组XLSX', false, ...
            '可留空；多人统计时填写file_name、subject_id、group等');
        addFieldLabel(grid, 4, '统计表格名称', ...
            '填写基本名称，不要写路径；扩展名自动补为.xlsx');
        controls.excelName = uieditfield(grid, 'text', ...
            'Value', 'time_domain_statistics');
        controls.excelName.Layout.Row = 4;
        controls.excelName.Layout.Column = 2;
        controls.excelEnabled = addCheckbox(grid, 5, ...
            '导出统计表格（XLSX）', true, ...
            '关闭后仍保存每文件MAT，完全不创建任何XLSX');
        controls.excelEnabled.ValueChangedFcn = @(~, ~) updateExcelControls();
        controls.timeDomainEnabled = addCheckbox(grid, 6, ...
            '计算方法：时域统计特征', true, ...
            '参考说明5.1；可与5.2/5.3单独或同时运行');
        controls.frequencyEnabled = addCheckbox(grid, 7, ...
            '计算方法：频谱与频带输出', false, ...
            '参考说明5.2；完整PSD、频带、谱形、1/f、比值及FAA');
        controls.nonlinearEnabled = addCheckbox(grid, 8, ...
            '计算方法：熵与非线性动力学', false, ...
            '参考说明5.3；高计算量指标默认关闭');
        addFieldLabel(grid, 9, '缺失值处理', ...
            ['omit按指标忽略；插值/填零会改变数据；reject仅在超过阈值时', ...
            '拒绝通道或整文件']);
        controls.missingMethod = uidropdown(grid, 'Items', { ...
            'omit', 'linear', 'nearest', 'previous', 'zero', ...
            'reject_channel', 'reject_file'}, 'Value', 'omit');
        controls.missingMethod.Layout.Row = 9;
        controls.missingMethod.Layout.Column = 2;
        controls.maxMissing = addNumeric(grid, 10, '最大缺失比例', 0.20, ...
            'reject_channel/reject_file使用，范围0–1');
        controls.minSamples = addNumeric(grid, 11, '最少有效样本数', 3, ...
            '少于此值则该通道指标输出NaN');
        addFieldLabel(grid, 12, '方差/标准差归一化', ...
            'sample使用N-1；population使用N');
        controls.varianceNormalization = uidropdown(grid, ...
            'Items', {'sample', 'population'}, 'Value', 'sample');
        controls.varianceNormalization.Layout.Row = 12;
        controls.varianceNormalization.Layout.Column = 2;
        createInfoCard(grid, 13, 'MAT命名与结构', ...
            ['仅5.1/5.2/5.3分别使用专用英文后缀；启用多个版块时为', ...
            '_statistics。MAT始终保存完整非单值结果。']);
        createInfoCard(grid, 14, '统计表格结构', ...
            ['各版块在对应设置页选择自己的XLSX布局；总体页只控制是否', ...
            '创建统计表格。关闭XLSX不会影响MAT。']);
        updateExcelControls();
    end

    function buildIndividualTab()
        outer = uigridlayout(individualTab, [2, 1]);
        outer.RowHeight = {40, '1x'};
        outer.Padding = [12, 10, 12, 12];
        outer.BackgroundColor = colors.background;
        top = uigridlayout(outer, [1, 3]);
        top.ColumnWidth = {'1x', 170, 150};
        uilabel(top, 'Text', ...
            '每项独立计算；MAT始终保留。XLSX可选宽表、长表、两者或不导出。', ...
            'FontColor', colors.muted);
        controls.timeDomainLayout = uidropdown(top, ...
            'Items', {'wide', 'long', 'both', 'none'}, 'Value', 'wide', ...
            'Tooltip', '5.1 XLSX布局：宽表/长表/同时/不导出');
        uibutton(top, 'Text', '打开5.1说明', ...
            'ButtonPushedFcn', @openTimeDomainGuide);
        categoryTabs = uitabgroup(outer);
        buildLocationTab(uitab(categoryTabs, 'Title', '位置与幅度'));
        buildDispersionTab(uitab(categoryTabs, 'Title', '离散程度'));
        buildShapeTab(uitab(categoryTabs, 'Title', '分布形状'));
        buildChangeTab(uitab(categoryTabs, 'Title', '变化速度'));
        buildHjorthTab(uitab(categoryTabs, 'Title', 'Hjorth参数'));
    end

    function buildFrequencyTab()
        outer = uigridlayout(frequencyTab, [2, 1]);
        outer.RowHeight = {40, '1x'};
        outer.Padding = [12, 10, 12, 12];
        outer.BackgroundColor = colors.background;
        top = uigridlayout(outer, [1, 2]);
        top.ColumnWidth = {'1x', 150};
        uilabel(top, 'Text', ...
            ['每项可独立启用；PSD与周期峰的导出方式在各自指标页设置，', ...
            'MAT始终保存完整结果。'], 'FontColor', colors.muted);
        uibutton(top, 'Text', '打开5.2说明', ...
            'ButtonPushedFcn', @openFrequencyGuide);
        tabs = uitabgroup(outer);
        buildPSDTab(uitab(tabs, 'Title', 'PSD与Welch'));
        buildBandTab(uitab(tabs, 'Title', '频带功率'));
        buildSpectralShapeTab(uitab(tabs, 'Title', '频谱形状'));
        buildAperiodicTab(uitab(tabs, 'Title', '1/f与周期峰'));
        buildRatioFAATab(uitab(tabs, 'Title', '比值与FAA'));
    end

    function buildPSDTab(tab)
        grid = metricGrid(tab, 8);
        controls.psd = metricCheck(grid, 1, '完整PSD', true, ...
            'frequency_hz、power、power_db_hz；MAT始终保留完整频率向量');
        controls.frequencyWindow = addNumeric(grid, 2, ...
            'Welch窗口秒数', 2, '常见1–4秒；实际窗口不会超过数据长度');
        controls.frequencyOverlap = addNumeric(grid, 3, ...
            'Welch重叠比例', 0.5, '范围0–小于1');
        controls.frequencyNfft = addNumeric(grid, 4, ...
            'Welch NFFT', 512, '自动不小于窗口长度的下一个2次幂');
        controls.frequencyDetrend = addDropdown(grid, 5, '去趋势方式', ...
            {'none', 'constant', 'linear'}, 'constant', ...
            'constant去均值；linear去线性趋势；none不处理');
        controls.frequencyMinSamples = addNumeric(grid, 6, ...
            '频谱最少样本数', 64, '不足时该通道输出NaN并记录状态');
        controls.psdExcelMode = addDropdown(grid, 7, 'PSD导出格式', ...
            {'long', 'wide', 'separate', 'none'}, 'long', ...
            ['long逐频点；wide频率展开为列；separate独立工作簿；', ...
            'none不导出PSD到XLSX，MAT仍完整保留']);
        controls.psdExcelMode.ValueChangedFcn = @(~, ~) updateExcelControls();
        controls.spectrumStride = addNumeric(grid, 8, 'PSD导出频点步长', 1, ...
            '1表示全部频点；仅影响XLSX，MAT始终保存完整PSD');
    end

    function buildBandTab(tab)
        grid = metricGrid(tab, 13);
        controls.absolutePower = metricCheck(grid, 1, ...
            '绝对频带功率', true, '每个频带一个标量，单位继承输入量纲平方');
        controls.relativePower = metricCheck(grid, 2, ...
            '相对频带功率', true, 'band_power / total_power');
        controls.logPower = metricCheck(grid, 3, ...
            '对数频带功率', true, '可选择dB或log10变换');
        controls.logTransform = addDropdown(grid, 4, '对数方式', ...
            {'db', 'log10'}, 'db', 'db=10log10(power)；log10为直接常用对数');
        controls.totalRange = addText(grid, 5, '总功率范围Hz', ...
            '[1 45]', '相对功率分母及total_power使用');
        controls.deltaRange = addText(grid, 6, 'Delta范围Hz', '[1 4]', ...
            '频带上下界必须递增');
        controls.thetaRange = addText(grid, 7, 'Theta范围Hz', '[4 8]', ...
            '频带上下界必须递增');
        controls.alphaRange = addText(grid, 8, 'Alpha范围Hz', '[8 13]', ...
            'FAA默认使用名称为alpha的频带');
        controls.betaRange = addText(grid, 9, 'Beta范围Hz', '[13 30]', ...
            '频带上下界必须递增');
        controls.gammaRange = addText(grid, 10, 'Gamma范围Hz', '[30 45]', ...
            '上限超过Nyquist时自动无有效频点');
        controls.customBands = addText(grid, 11, '自定义频带', '', ...
            '格式：low_alpha:8-10;high_alpha:10-13，可留空');
    end

    function buildSpectralShapeTab(tab)
        grid = metricGrid(tab, 10);
        controls.spectralShape = metricCheck(grid, 1, ...
            '峰频、峰功率、质心、中位频率、带宽', true, ...
            '均为通道级标量');
        controls.spectralFlatness = metricCheck(grid, 2, ...
            '频谱平坦度（补充）', true, '几何均值/算术均值，接近1更平坦');
        controls.spectralEdge = metricCheck(grid, 3, ...
            '谱边缘频率SEF（补充）', true, '累计功率达到指定比例的频率');
        controls.individualAlphaPeak = metricCheck(grid, 4, ...
            '个体Alpha峰IAF（补充）', true, '指定Alpha搜索范围内的最大功率频率');
        controls.shapeRange = addText(grid, 5, '谱形统计范围Hz', ...
            '[1 45]', '峰、质心、中位频率、带宽和平坦度使用');
        controls.edgeFractions = addText(grid, 6, 'SEF比例', ...
            '[0.90 0.95]', '每个比例生成一个标量列');
        controls.alphaPeakRange = addText(grid, 7, 'IAF搜索范围Hz', ...
            '[7 14]', '常用7–14Hz，可按研究方案固定');
    end

    function buildAperiodicTab(tab)
        grid = metricGrid(tab, 10);
        controls.aperiodic = metricCheck(grid, 1, ...
            '非周期1/f成分与周期峰', false, ...
            '输出exponent、offset、fit_r2及全部检测峰列表');
        controls.aperiodicRange = addText(grid, 2, '拟合范围Hz', ...
            '[2 45]', '0Hz不参与log-log拟合');
        controls.aperiodicExclusions = addText(grid, 3, ...
            '排除频段Hz', '[48 52; 58 62]', ...
            'N×2矩阵；常用于排除50/60Hz线噪声，可填[]');
        controls.peakThreshold = addNumeric(grid, 4, ...
            '周期峰阈值MAD倍数', 2, '相对初始1/f残差的稳健尺度');
        controls.minPeakDistance = addNumeric(grid, 5, ...
            '最小峰间距Hz', 1, '避免相邻频点重复记峰');
        controls.maxPeriodicPeaks = addNumeric(grid, 6, ...
            '每通道最多周期峰数', 6, '0表示不保存峰列表，但仍拟合1/f');
        controls.periodicPeakExcelMode = addDropdown(grid, 7, ...
            '周期峰导出格式', {'long', 'wide', 'separate', 'none'}, 'long', ...
            ['long逐峰；wide按峰序号展开；separate独立工作簿；', ...
            'none不导出峰列表到XLSX，MAT仍完整保留']);
    end

    function buildRatioFAATab(tab)
        grid = metricGrid(tab, 11);
        controls.thetaBetaRatio = metricCheck(grid, 1, ...
            'Theta/Beta比值', false, '建议仅在预注册研究假设下启用');
        controls.alphaThetaRatio = metricCheck(grid, 2, ...
            'Alpha/Theta比值', false, '建议仅在预注册研究假设下启用');
        controls.highLowRatio = metricCheck(grid, 3, ...
            '(Alpha+Beta)/(Delta+Theta)', false, ...
            '建议仅在预注册研究假设下启用');
        controls.faa = metricCheck(grid, 4, ...
            '额叶Alpha不对称FAA', false, '按左右同源电极对输出标量');
        controls.faaPairs = addText(grid, 5, 'FAA电极对', ...
            'F3-F4;F7-F8', '格式：左-右;左-右，名称不区分大小写');
        controls.faaDirection = addDropdown(grid, 6, 'FAA符号方向', ...
            {'right_minus_left', 'left_minus_right'}, 'right_minus_left', ...
            '必须在研究方案中固定并报告');
        controls.faaTransform = addDropdown(grid, 7, 'FAA对数变换', ...
            {'natural_log', 'log10', 'db'}, 'natural_log', ...
            '经典FAA常用自然对数功率差');
    end

    function buildNonlinearTab()
        outer = uigridlayout(nonlinearTab, [2, 1]);
        outer.RowHeight = {40, '1x'};
        outer.Padding = [12, 10, 12, 12];
        outer.BackgroundColor = colors.background;
        top = uigridlayout(outer, [1, 4]);
        top.ColumnWidth = {'1x', 155, 155, 150};
        uilabel(top, 'Text', ...
            ['每项可独立启用；“补充”是常用扩展；“探索性”参数敏感，', ...
            '默认关闭；MAT始终保留。'], 'FontColor', colors.muted);
        controls.nonlinearScalarLayout = uidropdown(top, ...
            'Items', {'wide', 'long', 'both', 'none'}, 'Value', 'wide', ...
            'Tooltip', '5.3标量XLSX布局');
        controls.nonlinearSeriesMode = uidropdown(top, ...
            'Items', {'long', 'wide', 'separate', 'none'}, 'Value', 'long', ...
            'Tooltip', '5.3尺度/半径/延迟序列XLSX布局');
        uibutton(top, 'Text', '打开5.3说明', ...
            'ButtonPushedFcn', @openNonlinearGuide);
        tabs = uitabgroup(outer);
        buildEntropyTab(uitab(tabs, 'Title', '熵与容差'));
        buildSymbolTab(uitab(tabs, 'Title', '排列、SVD与LZ'));
        buildFractalTab(uitab(tabs, 'Title', 'Hurst、DFA与分形'));
        buildExploratoryTab(uitab(tabs, 'Title', '多尺度与探索性'));
        buildRQATab(uitab(tabs, 'Title', 'RQA'));
    end

    function buildEntropyTab(tab)
        grid = metricGrid(tab, 21);
        controls.spectralEntropy = metricCheck(grid, 1, ...
            '频谱熵 spectral_entropy', true, '标量；Welch PSD归一化熵');
        controls.differentialEntropy = metricCheck(grid, 2, ...
            '差分熵 differential_entropy', true, '标量；Gaussian估计，记录方法');
        controls.sampleEntropy = metricCheck(grid, 3, ...
            '样本熵 sample_entropy', true, '标量；不计自匹配');
        controls.approximateEntropy = metricCheck(grid, 4, ...
            '近似熵 approximate_entropy', true, '标量；包含自匹配');
        controls.fuzzyEntropy = metricCheck(grid, 5, ...
            '模糊熵 fuzzy_entropy（补充）', false, '标量；连续相似度核');
        controls.entropyM = addNumeric(grid, 6, '嵌入维数 m', 2, ...
            'SampEn/ApEn/FuzzyEn共用，常见2或3');
        controls.entropyR = addNumeric(grid, 7, '容差 r', 0.2, ...
            '默认0.2×标准差；也可选择绝对值');
        controls.entropyRMode = addDropdown(grid, 8, 'r解释方式', ...
            {'std', 'absolute'}, 'std', 'std表示r×标准差');
        controls.fuzzyPower = addNumeric(grid, 9, '模糊核幂次', 2, ...
            '仅模糊熵使用，常见2');
        controls.spectralRange = addText(grid, 10, '频谱熵频率范围Hz', ...
            '[0.5 45]', '超过Nyquist的上限自动截断');
        controls.spectralWindow = addNumeric(grid, 11, ...
            'Welch窗口秒数', 2, '常见1–4秒');
        controls.spectralOverlap = addNumeric(grid, 12, ...
            'Welch重叠比例', 0.5, '范围0–小于1');
        controls.spectralNfft = addNumeric(grid, 13, ...
            'Welch NFFT', 512, '至少8；自动不小于窗口的2次幂');
        controls.spectralNormalized = addCheckbox(grid, 14, ...
            '频谱熵归一化到0–1', true, '除以log2(有效频点数)');
        controls.nonlinearMinSamples = addNumeric(grid, 15, ...
            '非线性最少样本数', 64, '不足时该通道指标为NaN');
        controls.nonlinearMaxSamples = addNumeric(grid, 16, ...
            '计算最大样本数', 3000, '长记录均匀抽样，控制O(N²)成本');
        controls.entropySpectralMethod = addDropdown(grid, 17, ...
            '频谱熵PSD算法', {'welch', 'periodogram'}, 'welch', ...
            'Welch更稳健；periodogram保留更高方差的单段谱');
        controls.entropyStandardization = addDropdown(grid, 18, ...
            '模板熵标准化', {'zscore', 'demean', 'none'}, 'zscore', ...
            'SampEn/ApEn/FuzzyEn/MSE计算前处理');
        controls.entropyDistance = addDropdown(grid, 19, ...
            '模板距离', {'chebyshev', 'euclidean'}, 'chebyshev', ...
            'Chebyshev是SampEn/ApEn常用定义；也可选欧氏距离');
        controls.differentialMethod = addDropdown(grid, 20, ...
            '差分熵估计', {'gaussian', 'histogram'}, 'gaussian', ...
            'Gaussian参数估计或等宽直方图估计');
        controls.differentialBins = addNumeric(grid, 21, ...
            '差分熵直方图箱数', 32, '仅histogram方法使用，范围4–512');
    end

    function buildSymbolTab(tab)
        grid = metricGrid(tab, 12);
        controls.permutationEntropy = metricCheck(grid, 1, ...
            '排列熵 permutation_entropy', true, '标量；保存维数、延迟与归一化');
        controls.svdEntropy = metricCheck(grid, 2, ...
            'SVD熵 svd_entropy（补充）', false, '标量；嵌入矩阵奇异值分布');
        controls.lempelZiv = metricCheck(grid, 3, ...
            'Lempel-Ziv复杂度', true, '标量；同时导出原始和归一化值');
        controls.permutationDimension = addNumeric(grid, 4, ...
            '排列维数', 3, '常见3–5，最大7');
        controls.permutationDelay = addNumeric(grid, 5, ...
            '排列延迟', 1, '正整数采样点');
        controls.permutationNormalized = addCheckbox(grid, 6, ...
            '排列熵归一化', true, '除以log2(m!)');
        controls.svdDimension = addNumeric(grid, 7, 'SVD嵌入维数', 3, ...
            '仅SVD熵使用');
        controls.svdDelay = addNumeric(grid, 8, 'SVD延迟', 1, ...
            '仅SVD熵使用');
        controls.svdNormalized = addCheckbox(grid, 9, ...
            'SVD熵归一化', true, '除以log2(有效奇异值数)');
        controls.lzBinarization = addDropdown(grid, 10, 'LZ二值化', ...
            {'median', 'mean', 'zero'}, 'median', '保存二值化规则');
        controls.lzNormalized = addCheckbox(grid, 11, ...
            'LZ复杂度归一化', true, 'c(n)×log2(n)/n');
    end

    function buildFractalTab(tab)
        grid = metricGrid(tab, 15);
        controls.hurst = metricCheck(grid, 1, 'Hurst指数', true, ...
            '标量H及fit_r2');
        controls.dfa = metricCheck(grid, 2, 'DFA', true, ...
            'alpha与fit_r2为标量；全部scale曲线进入长表');
        controls.higuchiFD = metricCheck(grid, 3, 'Higuchi FD', true, ...
            '标量；保存kmax');
        controls.petrosianFD = metricCheck(grid, 4, 'Petrosian FD', true, ...
            '标量；基于导数符号变化');
        controls.katzFD = metricCheck(grid, 5, 'Katz FD', true, ...
            '标量；时间-幅度曲线几何长度');
        controls.hurstScaleMin = addNumeric(grid, 6, 'Hurst最小尺度', 16, ...
            '样本数');
        controls.hurstScaleMax = addNumeric(grid, 7, 'Hurst最大尺度', 512, ...
            '自动受记录长度限制');
        controls.hurstScales = addNumeric(grid, 8, 'Hurst尺度数', 12, ...
            '对数均匀尺度');
        controls.dfaScaleMin = addNumeric(grid, 9, 'DFA最小尺度', 16, ...
            '样本数');
        controls.dfaScaleMax = addNumeric(grid, 10, 'DFA最大尺度', 512, ...
            '自动受记录长度限制');
        controls.dfaScales = addNumeric(grid, 11, 'DFA尺度数', 12, ...
            '全部有效尺度逐点导出');
        controls.dfaOrder = addNumeric(grid, 12, 'DFA去趋势阶数', 1, ...
            '常见1；支持1–3');
        controls.higuchiKmax = addNumeric(grid, 13, 'Higuchi kmax', 10, ...
            '常见5–20');
    end

    function buildExploratoryTab(tab)
        grid = metricGrid(tab, 17);
        controls.multiscaleEntropy = metricCheck(grid, 1, ...
            '多尺度样本熵 MSE（补充）', false, ...
            '均值/复杂度指数为标量；每个scale全部进入长表');
        controls.correlationDimension = metricCheck(grid, 2, ...
            '相关维数（探索性）', false, ...
            '维数与fit_r2标量；radius曲线全部导出');
        controls.largestLyapunov = metricCheck(grid, 3, ...
            '最大Lyapunov指数（探索性）', false, ...
            '指数与fit_r2标量；lag发散曲线全部导出');
        controls.mseMaxScale = addNumeric(grid, 4, 'MSE最大尺度', 20, ...
            '常见10–30；每尺度使用同一SampEn参数');
        controls.corrDimension = addNumeric(grid, 5, '相关维数嵌入维数', 3, ...
            '探索参数，需预注册');
        controls.corrDelay = addNumeric(grid, 6, '相关维数延迟', 1, ...
            '采样点');
        controls.corrTheiler = addNumeric(grid, 7, '相关维数Theiler窗', 20, ...
            '排除时间邻近点');
        controls.corrMaxPoints = addNumeric(grid, 8, '相关维数最大点数', 1000, ...
            '控制距离计算规模');
        controls.corrNRadii = addNumeric(grid, 9, '相关维数半径数', 12, ...
            '全部radius/C(r)逐点导出');
        controls.corrPercentiles = addText(grid, 10, '半径距离百分位', ...
            '[5 60]', '二元素，单位百分比');
        controls.lyapDimension = addNumeric(grid, 11, 'Lyapunov嵌入维数', 3, ...
            '探索参数');
        controls.lyapDelay = addNumeric(grid, 12, 'Lyapunov延迟', 1, ...
            '采样点');
        controls.lyapTheiler = addNumeric(grid, 13, 'Lyapunov Theiler窗', 20, ...
            '排除时间邻近点');
        controls.lyapMaxPoints = addNumeric(grid, 14, 'Lyapunov最大点数', 1000, ...
            '控制计算规模');
        controls.lyapMaxSteps = addNumeric(grid, 15, 'Lyapunov拟合最大步数', 20, ...
            'lag曲线全部导出');
    end

    function buildRQATab(tab)
        grid = metricGrid(tab, 16);
        controls.rqa = metricCheck(grid, 1, '递归量化分析 RQA', false, ...
            '导出RR/DET/Lmax/Lmean/ENT/RATIO/DIV/LAM/TT/Vmax/ART/TREND');
        controls.rqaDimension = addNumeric(grid, 2, '嵌入维数', 3, ...
            '常见2–5');
        controls.rqaDelay = addNumeric(grid, 3, '延迟', 1, '采样点');
        controls.rqaMaxPoints = addNumeric(grid, 4, '最大嵌入点数', 1000, ...
            'RQA为O(N²)，建议不超过2000');
        controls.rqaThresholdMode = addDropdown(grid, 5, '阈值模式', ...
            {'fixed', 'target_rr'}, 'fixed', ...
            'fixed使用epsilon；target_rr使用目标复现率分位数');
        controls.rqaEpsilon = addNumeric(grid, 6, 'epsilon', 0.5, ...
            'z-score后相空间欧氏距离阈值');
        controls.rqaTargetRR = addNumeric(grid, 7, '目标RR', 0.05, ...
            'target_rr模式使用，范围0–1');
        controls.rqaTheiler = addNumeric(grid, 8, 'Theiler窗', 1, ...
            '排除主对角附近时间相关点');
        controls.rqaMinDiagonal = addNumeric(grid, 9, '最小对角线长', 2, ...
            'DET等指标使用');
        controls.rqaMinVertical = addNumeric(grid, 10, '最小垂直线长', 2, ...
            'LAM/TT等指标使用');
        controls.rqaStoreMat = addCheckbox(grid, 11, ...
            '完整递归矩阵保存到MAT', true, '常规做法；保真且不撑大XLSX');
        controls.rqaExportExcel = addCheckbox(grid, 12, ...
            '完整递归点导出到XLSX', false, ...
            '显式开启后按row_index/column_index逐点长表导出');
        controls.rqaDistance = addDropdown(grid, 13, '相空间距离', ...
            {'euclidean', 'chebyshev'}, 'euclidean', ...
            '固定阈值大小依赖距离定义，必须记录');
        controls.rqaMatrixMode = addDropdown(grid, 14, '递归矩阵XLSX形式', ...
            {'coordinates', 'dense'}, 'coordinates', ...
            'coordinates只列递归点；dense按0/1矩阵拆分工作簿');
        controls.rqaLocation = addDropdown(grid, 15, '递归点导出位置', ...
            {'main', 'separate'}, 'main', ...
            'dense始终单独工作簿；coordinates可在主表或独立工作簿');
    end

    function buildLocationTab(tab)
        grid = metricGrid(tab, 13);
        controls.mean = metricCheck(grid, 1, '均值 mean', true, '基线/中心位置');
        controls.median = metricCheck(grid, 2, '中位数 median', true, '稳健中心位置');
        controls.min = metricCheck(grid, 3, '最小值 min', true, '动态下界');
        controls.max = metricCheck(grid, 4, '最大值 max', true, '动态上界');
        controls.range = metricCheck(grid, 5, '极差 range', true, 'max-min');
        controls.peakToPeak = metricCheck(grid, 6, ...
            '峰峰值 peak_to_peak', true, '与range同值，保留标准命名');
        controls.quantiles = metricCheck(grid, 7, ...
            '分位数 quantiles（补充）', false, '稳健描述尾部与区间');
        controls.trimmedMean = metricCheck(grid, 8, ...
            '截尾均值 trimmed_mean（补充）', false, '降低极端值影响');
        controls.energy = metricCheck(grid, 9, ...
            '能量 energy（补充）', false, '平方和，受记录长度影响');
        controls.sumAbs = metricCheck(grid, 10, ...
            '绝对值和 sum_abs（补充）', false, '幅度总量，受记录长度影响');
        controls.quantileText = addText(grid, 11, '分位点', ...
            '[0.05 0.25 0.75 0.95]', '仅quantiles启用时使用，范围0–1');
        controls.trimPercent = addNumeric(grid, 12, ...
            '单侧截尾百分比', 10, '仅trimmed_mean使用，范围0–小于50');
        controls.quantileMethod = addDropdown(grid, 13, '分位数算法', ...
            {'linear', 'nearest', 'lower', 'higher', 'midpoint'}, 'linear', ...
            '控制样本位置非整数时的插值方式');
    end

    function buildDispersionTab(tab)
        grid = metricGrid(tab, 9);
        controls.variance = metricCheck(grid, 1, '方差 variance', true, '信号波动');
        controls.std = metricCheck(grid, 2, '标准差 std', true, '方差平方根');
        controls.mad = metricCheck(grid, 3, 'MAD', true, '中位绝对偏差，稳健');
        controls.iqr = metricCheck(grid, 4, 'IQR', true, '四分位距，稳健');
        controls.rms = metricCheck(grid, 5, 'RMS', true, '均方根幅度');
        controls.cv = metricCheck(grid, 6, ...
            '变异系数 coefficient_of_variation（补充）', false, ...
            'std/abs(mean)；均值为0时输出NaN');
        controls.madMethod = addDropdown(grid, 7, 'MAD算法', ...
            {'median', 'mean'}, 'median', ...
            '中位绝对偏差更稳健；mean为平均绝对偏差');
    end

    function buildShapeTab(tab)
        grid = metricGrid(tab, 8);
        controls.skewness = metricCheck(grid, 1, ...
            '偏度 skewness', true, '分布非对称性');
        controls.kurtosis = metricCheck(grid, 2, ...
            '峰度 kurtosis', true, '标准化四阶矩；正态分布约3');
        controls.shapeBiasCorrection = addDropdown(grid, 3, ...
            '偏度/峰度偏差校正', {'biased', 'bias_corrected'}, 'biased', ...
            'bias_corrected适合有限样本；biased保持原矩估计');
    end

    function buildChangeTab(tab)
        grid = metricGrid(tab, 10);
        controls.meanAbsDiff = metricCheck(grid, 1, ...
            '平均绝对差 mean_abs_diff', true, '相邻样本平均变化');
        controls.lineLength = metricCheck(grid, 2, ...
            '线长 line_length', true, '相邻差绝对值之和');
        controls.zeroCross = metricCheck(grid, 3, ...
            '零交叉率 zero_cross_rate', true, '符号切换速度');
        controls.lineNormalization = addDropdown(grid, 4, ...
            '线长归一化', {'none', 'per_sample', 'per_second'}, 'none', ...
            '跨记录长度比较时建议per_sample或per_second');
        controls.zeroThreshold = addNumeric(grid, 5, ...
            '零交叉阈值', 0, '忽略阈值范围内的小波动，必须≥0');
        controls.zeroReference = addDropdown(grid, 6, ...
            '零交叉参考中心', {'mean', 'median', 'zero'}, 'mean', ...
            '减均值、减中位数或直接相对0判断');
        controls.zeroNormalization = addDropdown(grid, 7, ...
            '零交叉归一化', {'proportion', 'per_second'}, 'proportion', ...
            '比例或每秒次数');
    end

    function buildHjorthTab(tab)
        grid = metricGrid(tab, 8);
        controls.hjorthActivity = metricCheck(grid, 1, ...
            'Activity', true, '信号方差');
        controls.hjorthMobility = metricCheck(grid, 2, ...
            'Mobility', true, '一阶差分方差与原信号方差之比的平方根');
        controls.hjorthComplexity = metricCheck(grid, 3, ...
            'Complexity', true, '导数mobility与原信号mobility之比');
    end

    function buildLogTab()
        grid = uigridlayout(logTab, [2, 1]);
        grid.RowHeight = {36, '1x'};
        grid.Padding = [14, 14, 14, 14];
        top = uigridlayout(grid, [1, 2]);
        top.ColumnWidth = {'1x', 110};
        uilabel(top, 'Text', '失败文件会被跳过并记录，成功文件继续汇总。', ...
            'FontColor', colors.muted);
        uibutton(top, 'Text', '清空显示', ...
            'ButtonPushedFcn', @(~, ~) set(controls.log, 'Value', {''}));
        controls.log = uitextarea(grid, 'Editable', 'off', ...
            'FontName', 'Consolas', 'Value', {'等待运行。'});
    end

    function grid = metricGrid(parent, minimumRows)
        grid = uigridlayout(parent, [max(minimumRows, 12), 3], ...
            'Scrollable', 'on', 'BackgroundColor', colors.background, ...
            'Tag', 'StatisticsMetricScroll');
        grid.ColumnWidth = {330, 190, '1x'};
        grid.RowHeight = repmat({40}, 1, max(minimumRows, 12));
        grid.Padding = [18, 16, 18, 16];
        grid.RowSpacing = 8;
    end

    function control = metricCheck(grid, row, textValue, value, helpText)
        label = uilabel(grid, 'Text', textValue, 'FontWeight', 'bold');
        label.Layout.Row = row;
        label.Layout.Column = 1;
        control = uicheckbox(grid, 'Text', '计算（MAT保留）', 'Value', value);
        control.Layout.Row = row;
        control.Layout.Column = 2;
        helper = uilabel(grid, 'Text', helpText, ...
            'FontColor', colors.muted, 'WordWrap', 'on');
        helper.Layout.Row = row;
        helper.Layout.Column = 3;
    end

    function control = addCheckbox(grid, row, labelText, value, helpText)
        label = uilabel(grid, 'Text', labelText, 'FontWeight', 'bold');
        label.Layout.Row = row;
        label.Layout.Column = 1;
        control = uicheckbox(grid, 'Text', '启用', 'Value', value);
        control.Layout.Row = row;
        control.Layout.Column = 2;
        helper = uilabel(grid, 'Text', helpText, ...
            'FontColor', colors.muted, 'WordWrap', 'on');
        helper.Layout.Row = row;

        if numel(grid.ColumnWidth) >= 4
            helper.Layout.Column = [3, 4];
        else
            helper.Layout.Column = 3;
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

    function control = addDropdown(grid, row, labelText, items, value, helpText)
        addFieldLabel(grid, row, labelText, helpText);
        control = uidropdown(grid, 'Items', items, 'Value', value);
        control.Layout.Row = row;
        control.Layout.Column = 2;
    end

    function addFieldLabel(grid, row, labelText, helpText)
        label = uilabel(grid, 'Text', labelText, 'FontWeight', 'bold');
        label.Layout.Row = row;
        label.Layout.Column = 1;
        helper = uilabel(grid, 'Text', helpText, ...
            'FontColor', colors.muted, 'WordWrap', 'on');
        helper.Layout.Row = row;

        if numel(grid.ColumnWidth) >= 4
            helper.Layout.Column = [3, 4];
        else
            helper.Layout.Column = 3;
        end
    end

    function field = addPathRow(grid, row, labelText, directoryMode, helpText)
        label = uilabel(grid, 'Text', labelText, 'FontWeight', 'bold');
        label.Layout.Row = row;
        label.Layout.Column = 1;
        field = uieditfield(grid, 'text');
        field.Layout.Row = row;
        field.Layout.Column = 2;
        button = uibutton(grid, 'Text', '浏览', ...
            'ButtonPushedFcn', @(~, ~) browse(field, directoryMode));
        button.Layout.Row = row;
        button.Layout.Column = 3;
        helper = uilabel(grid, 'Text', helpText, ...
            'FontColor', colors.muted, 'WordWrap', 'on');
        helper.Layout.Row = row;
        helper.Layout.Column = 4;
    end

    function browse(field, directoryMode)
        if directoryMode
            selected = uigetdir(pwd, '选择目录');

            if ~isequal(selected, 0)
                field.Value = selected;
            end
        else
            [file, folder] = uigetfile({'*.xlsx', 'Excel工作簿 (*.xlsx)'}, ...
                '选择分组XLSX');

            if ~isequal(file, 0)
                field.Value = fullfile(folder, file);
            end
        end
    end

    function createInfoCard(grid, row, titleText, bodyText)
        card = uipanel(grid, 'BorderType', 'line', ...
            'BackgroundColor', [0.93, 0.96, 1.00]);
        card.Layout.Row = row;
        card.Layout.Column = [1, 4];
        cardGrid = uigridlayout(card, [2, 1]);
        cardGrid.RowHeight = {23, '1x'};
        cardGrid.Padding = [12, 7, 12, 7];
        cardGrid.BackgroundColor = [0.93, 0.96, 1.00];
        uilabel(cardGrid, 'Text', titleText, 'FontWeight', 'bold', ...
            'FontColor', colors.text);
        uilabel(cardGrid, 'Text', bodyText, 'WordWrap', 'on', ...
            'FontColor', colors.muted);
    end

    function options = collectOptions()
        options.inputDir = string(strtrim(controls.inputDir.Value));
        options.outputDir = string(strtrim(controls.outputDir.Value));
        options.groupFile = string(strtrim(controls.groupFile.Value));
        options.excelName = string(strtrim(controls.excelName.Value));
        options.excel.enabled = controls.excelEnabled.Value;
        options.excel.psdMode = string(controls.psdExcelMode.Value);
        options.excel.periodicPeakMode = ...
            string(controls.periodicPeakExcelMode.Value);
        options.excel.spectrumStride = controls.spectrumStride.Value;
        options.excel.timeDomainLayout = ...
            string(controls.timeDomainLayout.Value);
        options.excel.nonlinearScalarLayout = ...
            string(controls.nonlinearScalarLayout.Value);
        options.excel.nonlinearSeriesMode = ...
            string(controls.nonlinearSeriesMode.Value);
        options.excel.rqaLocation = string(controls.rqaLocation.Value);
        options.timeDomain.enabled = controls.timeDomainEnabled.Value;
        options.frequency.enabled = controls.frequencyEnabled.Value;
        options.nonlinear.enabled = controls.nonlinearEnabled.Value;
        metricMap = { ...
            'mean', 'mean'; 'median', 'median'; 'min', 'min'; 'max', 'max'; ...
            'range', 'range'; 'peakToPeak', 'peak_to_peak'; ...
            'quantiles', 'quantiles'; 'trimmedMean', 'trimmed_mean'; ...
            'energy', 'energy'; 'sumAbs', 'sum_abs'; ...
            'variance', 'variance'; 'std', 'std'; 'mad', 'mad'; ...
            'iqr', 'iqr'; 'rms', 'rms'; 'cv', 'coefficient_of_variation'; ...
            'skewness', 'skewness'; 'kurtosis', 'kurtosis'; ...
            'meanAbsDiff', 'mean_abs_diff'; 'lineLength', 'line_length'; ...
            'zeroCross', 'zero_cross_rate'; ...
            'hjorthActivity', 'hjorth_activity'; ...
            'hjorthMobility', 'hjorth_mobility'; ...
            'hjorthComplexity', 'hjorth_complexity'};
        metrics = strings(0, 1);

        for imetric = 1:size(metricMap, 1)
            if controls.(metricMap{imetric, 1}).Value
                metrics(end + 1) = string(metricMap{imetric, 2}); %#ok<AGROW>
            end
        end

        options.timeDomain.metrics = metrics(:)';
        options.timeDomain.varianceNormalization = ...
            string(controls.varianceNormalization.Value);
        options.timeDomain.quantiles = parseVector(controls.quantileText.Value);
        options.timeDomain.quantileMethod = string(controls.quantileMethod.Value);
        options.timeDomain.trimPercent = controls.trimPercent.Value;
        options.timeDomain.madMethod = string(controls.madMethod.Value);
        options.timeDomain.shapeBiasCorrection = ...
            string(controls.shapeBiasCorrection.Value);
        options.timeDomain.zeroCrossThreshold = controls.zeroThreshold.Value;
        options.timeDomain.zeroCrossReference = ...
            string(controls.zeroReference.Value);
        options.timeDomain.zeroCrossCenter = ...
            options.timeDomain.zeroCrossReference ~= "zero";
        options.timeDomain.zeroCrossNormalization = ...
            string(controls.zeroNormalization.Value);
        options.timeDomain.lineLengthNormalization = ...
            string(controls.lineNormalization.Value);
        frequencyMap = { ...
            'psd', 'psd'; 'absolutePower', 'absolute_power'; ...
            'relativePower', 'relative_power'; 'logPower', 'log_power'; ...
            'spectralShape', 'spectral_shape'; ...
            'spectralFlatness', 'spectral_flatness'; ...
            'spectralEdge', 'spectral_edge'; ...
            'individualAlphaPeak', 'individual_alpha_peak'; ...
            'aperiodic', 'aperiodic'; ...
            'thetaBetaRatio', 'theta_beta_ratio'; ...
            'alphaThetaRatio', 'alpha_theta_ratio'; ...
            'highLowRatio', 'high_low_ratio'; 'faa', 'faa'};
        frequencyMetrics = strings(0, 1);
        for imetric = 1:size(frequencyMap, 1)
            if controls.(frequencyMap{imetric, 1}).Value
                frequencyMetrics(end + 1) = ...
                    string(frequencyMap{imetric, 2}); %#ok<AGROW>
            end
        end
        options.frequency.metrics = frequencyMetrics(:)';
        options.frequency.minimumSamples = controls.frequencyMinSamples.Value;
        options.frequency.welch.windowSeconds = controls.frequencyWindow.Value;
        options.frequency.welch.overlap = controls.frequencyOverlap.Value;
        options.frequency.welch.nfft = controls.frequencyNfft.Value;
        options.frequency.welch.detrend = string(controls.frequencyDetrend.Value);
        [bandNames, bandRanges] = collectBands();
        options.frequency.bands.names = bandNames;
        options.frequency.bands.rangesHz = bandRanges;
        options.frequency.totalRangeHz = parseVector(controls.totalRange.Value);
        options.frequency.logTransform = string(controls.logTransform.Value);
        options.frequency.shape.frequencyRangeHz = ...
            parseVector(controls.shapeRange.Value);
        options.frequency.shape.edgeFractions = ...
            parseVector(controls.edgeFractions.Value);
        options.frequency.shape.alphaPeakRangeHz = ...
            parseVector(controls.alphaPeakRange.Value);
        options.frequency.aperiodic.frequencyRangeHz = ...
            parseVector(controls.aperiodicRange.Value);
        options.frequency.aperiodic.excludeRangesHz = ...
            parseRangeMatrix(controls.aperiodicExclusions.Value);
        options.frequency.aperiodic.peakThresholdSD = ...
            controls.peakThreshold.Value;
        options.frequency.aperiodic.minPeakDistanceHz = ...
            controls.minPeakDistance.Value;
        options.frequency.aperiodic.maxPeaks = controls.maxPeriodicPeaks.Value;
        options.frequency.faa.pairs = parsePairs(controls.faaPairs.Value);
        options.frequency.faa.direction = string(controls.faaDirection.Value);
        options.frequency.faa.transform = string(controls.faaTransform.Value);
        nonlinearMap = { ...
            'spectralEntropy', 'spectral_entropy'; ...
            'differentialEntropy', 'differential_entropy'; ...
            'sampleEntropy', 'sample_entropy'; ...
            'approximateEntropy', 'approximate_entropy'; ...
            'fuzzyEntropy', 'fuzzy_entropy'; ...
            'permutationEntropy', 'permutation_entropy'; ...
            'svdEntropy', 'svd_entropy'; 'lempelZiv', 'lempel_ziv'; ...
            'hurst', 'hurst'; 'dfa', 'dfa'; ...
            'higuchiFD', 'higuchi_fd'; 'petrosianFD', 'petrosian_fd'; ...
            'katzFD', 'katz_fd'; ...
            'multiscaleEntropy', 'multiscale_entropy'; ...
            'correlationDimension', 'correlation_dimension'; ...
            'largestLyapunov', 'largest_lyapunov'; 'rqa', 'rqa'};
        nonlinearMetrics = strings(0, 1);

        for imetric = 1:size(nonlinearMap, 1)
            if controls.(nonlinearMap{imetric, 1}).Value
                nonlinearMetrics(end + 1) = ...
                    string(nonlinearMap{imetric, 2}); %#ok<AGROW>
            end
        end

        options.nonlinear.metrics = nonlinearMetrics(:)';
        options.nonlinear.minimumSamples = controls.nonlinearMinSamples.Value;
        options.nonlinear.maxSamples = controls.nonlinearMaxSamples.Value;
        options.nonlinear.spectral.frequencyRangeHz = ...
            parseVector(controls.spectralRange.Value);
        options.nonlinear.spectral.method = ...
            string(controls.entropySpectralMethod.Value);
        options.nonlinear.spectral.windowSeconds = controls.spectralWindow.Value;
        options.nonlinear.spectral.overlap = controls.spectralOverlap.Value;
        options.nonlinear.spectral.nfft = controls.spectralNfft.Value;
        options.nonlinear.spectral.normalized = controls.spectralNormalized.Value;
        options.nonlinear.entropy.m = controls.entropyM.Value;
        options.nonlinear.entropy.r = controls.entropyR.Value;
        options.nonlinear.entropy.rMode = string(controls.entropyRMode.Value);
        options.nonlinear.entropy.distance = ...
            string(controls.entropyDistance.Value);
        options.nonlinear.entropy.standardization = ...
            string(controls.entropyStandardization.Value);
        options.nonlinear.entropy.fuzzyPower = controls.fuzzyPower.Value;
        options.nonlinear.differential.method = ...
            string(controls.differentialMethod.Value);
        options.nonlinear.differential.histogramBins = ...
            controls.differentialBins.Value;
        options.nonlinear.permutation.dimension = ...
            controls.permutationDimension.Value;
        options.nonlinear.permutation.delay = controls.permutationDelay.Value;
        options.nonlinear.permutation.normalized = ...
            controls.permutationNormalized.Value;
        options.nonlinear.svd.dimension = controls.svdDimension.Value;
        options.nonlinear.svd.delay = controls.svdDelay.Value;
        options.nonlinear.svd.normalized = controls.svdNormalized.Value;
        options.nonlinear.lempelZiv.binarization = ...
            string(controls.lzBinarization.Value);
        options.nonlinear.lempelZiv.normalized = controls.lzNormalized.Value;
        options.nonlinear.hurst.scaleMin = controls.hurstScaleMin.Value;
        options.nonlinear.hurst.scaleMax = controls.hurstScaleMax.Value;
        options.nonlinear.hurst.nScales = controls.hurstScales.Value;
        options.nonlinear.dfa.scaleMin = controls.dfaScaleMin.Value;
        options.nonlinear.dfa.scaleMax = controls.dfaScaleMax.Value;
        options.nonlinear.dfa.nScales = controls.dfaScales.Value;
        options.nonlinear.dfa.order = controls.dfaOrder.Value;
        options.nonlinear.fractal.higuchiKmax = controls.higuchiKmax.Value;
        options.nonlinear.multiscale.maxScale = controls.mseMaxScale.Value;
        options.nonlinear.correlationDimension.dimension = ...
            controls.corrDimension.Value;
        options.nonlinear.correlationDimension.delay = controls.corrDelay.Value;
        options.nonlinear.correlationDimension.theilerWindow = ...
            controls.corrTheiler.Value;
        options.nonlinear.correlationDimension.maxPoints = ...
            controls.corrMaxPoints.Value;
        options.nonlinear.correlationDimension.nRadii = controls.corrNRadii.Value;
        options.nonlinear.correlationDimension.radiusPercentiles = ...
            parseVector(controls.corrPercentiles.Value);
        options.nonlinear.lyapunov.dimension = controls.lyapDimension.Value;
        options.nonlinear.lyapunov.delay = controls.lyapDelay.Value;
        options.nonlinear.lyapunov.theilerWindow = controls.lyapTheiler.Value;
        options.nonlinear.lyapunov.maxPoints = controls.lyapMaxPoints.Value;
        options.nonlinear.lyapunov.maxSteps = controls.lyapMaxSteps.Value;
        options.nonlinear.rqa.embeddingDimension = controls.rqaDimension.Value;
        options.nonlinear.rqa.delay = controls.rqaDelay.Value;
        options.nonlinear.rqa.maxPoints = controls.rqaMaxPoints.Value;
        options.nonlinear.rqa.thresholdMode = ...
            string(controls.rqaThresholdMode.Value);
        options.nonlinear.rqa.distance = string(controls.rqaDistance.Value);
        options.nonlinear.rqa.epsilon = controls.rqaEpsilon.Value;
        options.nonlinear.rqa.targetRR = controls.rqaTargetRR.Value;
        options.nonlinear.rqa.theilerWindow = controls.rqaTheiler.Value;
        options.nonlinear.rqa.minDiagonalLine = ...
            controls.rqaMinDiagonal.Value;
        options.nonlinear.rqa.minVerticalLine = ...
            controls.rqaMinVertical.Value;
        options.nonlinear.rqa.storeMatrixInMat = controls.rqaStoreMat.Value;
        options.nonlinear.rqa.exportMatrixToExcel = ...
            controls.rqaExportExcel.Value;
        options.nonlinear.rqa.matrixExcelMode = ...
            string(controls.rqaMatrixMode.Value);
        options.missing.method = string(controls.missingMethod.Value);
        options.missing.maxFraction = controls.maxMissing.Value;
        options.missing.minimumValidSamples = controls.minSamples.Value;
        options = HyperEEG.MultiCH.main.StatisticsOptions(options);
    end

    function values = parseVector(value)
        normalized = regexprep(strtrim(string(value)), '[\[\],;]', ' ');
        values = sscanf(char(normalized), '%f')';

        if isempty(values) || any(~isfinite(values))
            error("无法解析数值向量：%s", value);
        end
    end

    function matrix = parseRangeMatrix(value)
        textValue = strtrim(string(value));
        if textValue == "" || textValue == "[]"
            matrix = zeros(0, 2);
            return;
        end
        rows = split(regexprep(textValue, '[\[\]]', ''), ';');
        matrix = nan(numel(rows), 2);
        for irow = 1:numel(rows)
            parsed = sscanf(char(regexprep(strtrim(rows(irow)), ',', ' ')), '%f')';
            if numel(parsed) ~= 2
                error("频率排除范围必须为N×2：%s", value);
            end
            matrix(irow, :) = parsed;
        end
    end

    function [names, ranges] = collectBands()
        names = ["delta", "theta", "alpha", "beta", "gamma"];
        ranges = [parseVector(controls.deltaRange.Value); ...
            parseVector(controls.thetaRange.Value); ...
            parseVector(controls.alphaRange.Value); ...
            parseVector(controls.betaRange.Value); ...
            parseVector(controls.gammaRange.Value)];
        customText = strtrim(string(controls.customBands.Value));
        if strlength(customText) == 0, return; end
        definitions = split(customText, ';');
        for idefinition = 1:numel(definitions)
            parts = split(strtrim(definitions(idefinition)), ':');
            if numel(parts) ~= 2 || strlength(strtrim(parts(1))) == 0
                error("自定义频带格式应为name:low-high。");
            end
            limits = sscanf(char(regexprep(parts(2), '[-,]', ' ')), '%f')';
            if numel(limits) ~= 2
                error("自定义频带范围无法解析：%s", definitions(idefinition));
            end
            names(end + 1) = strtrim(parts(1)); %#ok<AGROW>
            ranges(end + 1, :) = limits; %#ok<AGROW>
        end
    end

    function pairs = parsePairs(value)
        textValue = strtrim(string(value));
        if strlength(textValue) == 0
            pairs = strings(0, 2);
            return;
        end
        definitions = split(textValue, ';');
        pairs = strings(numel(definitions), 2);
        for ipair = 1:numel(definitions)
            parts = split(strtrim(definitions(ipair)), '-');
            if numel(parts) ~= 2
                error("FAA电极对格式应为左-右;左-右。");
            end
            pairs(ipair, :) = strtrim(parts(:))';
        end
    end

    function updateExcelControls()
        if ~isfield(controls, 'excelEnabled'), return; end
        if controls.excelEnabled.Value, state = 'on'; else, state = 'off'; end
        controls.excelName.Enable = state;
        exportControls = {'timeDomainLayout', 'psdExcelMode', ...
            'periodicPeakExcelMode', 'nonlinearScalarLayout', ...
            'nonlinearSeriesMode'};
        for icontrol = 1:numel(exportControls)
            name = exportControls{icontrol};
            if isfield(controls, name)
                controls.(name).Enable = state;
            end
        end
        if isfield(controls, 'spectrumStride')
            if controls.excelEnabled.Value && ...
                    string(controls.psdExcelMode.Value) ~= "none"
                controls.spectrumStride.Enable = 'on';
            else
                controls.spectrumStride.Enable = 'off';
            end
        end
    end

    function runStatistics(~, ~)
        setRunning(true);
        cleanupObject = onCleanup(@() setRunning(false));

        try
            options = collectOptions();

            if ~options.timeDomain.enabled && ~options.frequency.enabled && ...
                    ~options.nonlinear.enabled
                error("请至少启用一种统计计算方法。");
            end

            summary = HyperEEG.MultiCH.pipeline.Statistics_pipeline( ...
                options, @appendStatus);
            controls.status.Text = sprintf('完成：%d个文件', ...
                numel(summary.completedFiles));
            if strlength(summary.excelPath) > 0
                exportMessage = "统计表格：" + summary.excelPath;
            else
                exportMessage = "XLSX：未导出（按当前设置）";
            end
            uialert(fig, sprintf(['统计已完成。\n成功文件：%d\n跳过文件：%d\n', ...
                '%s'], numel(summary.completedFiles), ...
                numel(summary.skippedFiles), char(exportMessage)), ...
                'HyperEEG统计分析');
        catch ME
            controls.status.Text = '失败：请查看运行日志';
            appendStatus("错误：" + string(ME.message));
            uialert(fig, ME.message, '统计失败', 'Icon', 'error');
        end

        clear cleanupObject;
    end

    function setRunning(value)
        isRunning = value;

        if value
            controls.run.Enable = 'off';
            controls.status.Text = '正在统计，请稍候';
        else
            controls.run.Enable = 'on';
        end

        drawnow;
    end

    function appendStatus(message)
        timestamp = string(datetime('now', 'Format', 'HH:mm:ss'));
        current = string(controls.log.Value);

        if numel(current) == 1 && current == "等待运行。"
            current = strings(0, 1);
        end

        controls.log.Value = cellstr([current(:); ...
            "[" + timestamp + "] " + string(message)]);
        controls.status.Text = char(string(message));
        drawnow limitrate;
    end

    function openStatisticsGuide(~, ~)
        openProjectFile(fullfile(projectRoot(), 'txt', ...
            'HyperEEG统计分析指标说明.pdf'), '指标说明');
    end

    function openTimeDomainGuide(~, ~)
        openProjectFile(fullfile(projectRoot(), 'txt', ...
            'HyperEEG个体水平时域统计指标说明.pdf'), '5.1指标说明');
    end

    function openNonlinearGuide(~, ~)
        openProjectFile(fullfile(projectRoot(), 'txt', ...
            'HyperEEG熵与非线性指标说明.pdf'), '5.3指标说明');
    end

    function openFrequencyGuide(~, ~)
        openProjectFile(fullfile(projectRoot(), 'txt', ...
            'HyperEEG频谱与频带指标说明.pdf'), '5.2指标说明');
    end

    function openExampleFolder(~, ~)
        examplePath = fullfile(projectRoot(), '+HyperEEG', '+MultiCH', 'example');

        try
            if ispc
                winopen(examplePath);
            else
                open(examplePath);
            end
        catch ME
            uialert(fig, ME.message, '无法打开示例目录', 'Icon', 'error');
        end
    end

    function openProjectFile(pathValue, titleText)
        if ~isfile(pathValue)
            uialert(fig, "未找到文件：" + string(pathValue), ...
                '文件不存在', 'Icon', 'error');
            return;
        end

        try
            if ispc
                winopen(pathValue);
            else
                open(pathValue);
            end
        catch ME
            uialert(fig, ME.message, "无法打开" + string(titleText), ...
                'Icon', 'error');
        end
    end

    function rootPath = projectRoot()
        rootPath = fileparts(fileparts(fileparts(fileparts( ...
            mfilename('fullpath')))));
    end

    function closeWindow(~, ~)
        if isRunning
            uialert(fig, '统计运行期间请等待当前批次完成。', ...
                '任务运行中', 'Icon', 'warning');
            return;
        end

        delete(fig);
    end
end

function [outputData, info] = PreprocessArtifact( ...
        data, timeValues, sampleRate, method, options, channelInfo)
%PREPROCESSARTIFACT 自动伪迹核心算法的统一分派入口。
%   method支持none、robust、ica和asr；人工操作由main层独立函数负责。
%   outputData保持通道×采样点结构，info记录实际方法和处理统计。

    if nargin < 6
        channelInfo = [];
    end

    method = lower(string(method));

    % 将算法选择集中在此处，便于后续替换或增加新的自动方法。
    switch method
        case "none"
            outputData = data;
            info.method = method;
            info.repairedValueCount = 0;
        case "robust"
            [outputData, info] = robustRepair( ...
                data, timeValues, sampleRate, options);
        case "ica"
            [outputData, info] = icaRepair(data, sampleRate, options);
        case "asr"
            [outputData, info] = asrRepair( ...
                data, sampleRate, options, channelInfo);
        otherwise
            error("核心伪迹method必须为none、robust、ica或asr。");
    end

end

function [outputData, info] = robustRepair( ...
        data, timeValues, sampleRate, options)
%ROBUSTREPAIR 使用局部中位数和MAD修复孤立的极端瞬态。
%   该方法不会删除整段数据，阈值越大越宽松；原有NaN最终仍为NaN。

    outputData = double(data);
    blocks = HyperEEG.MultiCH.core.PreprocessContinuousBlocks(timeValues);
    windowSample = max(5, round( ...
        options.robustWindow_s * sampleRate));

    if mod(windowSample, 2) == 0
        windowSample = windowSample + 1;
    end

    repairedValueCount = 0;

    for iblock = 1:size(blocks, 1)
        blockIndex = blocks(iblock, 1):blocks(iblock, 2);
        [filledBlock, missingBlock] = ...
            HyperEEG.MultiCH.core.PreprocessFillMissing( ...
            outputData(:, blockIndex));
        % 局部中心和尺度均采用稳健统计，降低单个尖峰对阈值的影响。
        localCenter = movmedian(filledBlock, windowSample, 2);
        residual = filledBlock - localCenter;
        localScale = 1.4826 * movmedian( ...
            abs(residual), windowSample, 2);
        scaleFloor = max(median(localScale, 2), eps) * 1e-3;
        localScale = max(localScale, scaleFloor);
        artifactMask = abs(residual) > ...
            options.robustZ .* localScale & ~missingBlock;

        for ichannel = 1:size(filledBlock, 1)
            badIndex = find(artifactMask(ichannel, :));

            if isempty(badIndex)
                continue;
            end

            goodIndex = find(~artifactMask(ichannel, :) & ...
                ~missingBlock(ichannel, :));

            % 优先使用同一通道邻近好样本插值；信息不足时回退到局部中心。
            if numel(goodIndex) >= 2
                filledBlock(ichannel, badIndex) = interp1( ...
                    goodIndex, filledBlock(ichannel, goodIndex), ...
                    badIndex, 'linear', 'extrap');
            else
                filledBlock(ichannel, badIndex) = ...
                    localCenter(ichannel, badIndex);
            end

            repairedValueCount = repairedValueCount + numel(badIndex);
        end

        filledBlock(missingBlock) = NaN;
        outputData(:, blockIndex) = filledBlock;
    end

    info.method = "robust_local_median";
    info.robustZ = options.robustZ;
    info.window_s = options.robustWindow_s;
    info.repairedValueCount = repairedValueCount;

end

function [outputData, info] = icaRepair(data, sampleRate, options)
%ICAREPAIR 使用extended Infomax ICA识别并移除异常独立成分。
%   自动模式综合成分峰度和快速变化指标；显式成分序号优先于自动判定。
%   低通道数据的可分离成分有限，结果必须结合人工波形检查。

    model = HyperEEG.MultiCH.core.PreprocessICADecompose( ...
        data, sampleRate, options.icaMaxTrainingSamples);
    kurtosisZ = model.kurtosisZ(:);
    highFrequencyZ = model.highFrequencyZ(:);

    automaticRejection = isempty(options.icaRejectComponents);

    % 自动判定使用稳健Z分数；人工指定时不再应用自动比例上限。
    if automaticRejection
        rejectComponent = find( ...
            kurtosisZ > options.icaKurtosisZ | ...
            highFrequencyZ > options.icaHighFrequencyZ);
    else
        rejectComponent = unique(options.icaRejectComponents(:));
    end

    nComponent = model.componentCount;
    maxReject = max(0, floor( ...
        nComponent * options.icaMaxRejectFraction));
    rejectComponent = rejectComponent( ...
        rejectComponent >= 1 & rejectComponent <= nComponent);

    if ~automaticRejection && ...
            any(options.icaRejectComponents > nComponent)
        error("icaRejectComponents超过当前ICA成分数%d。", nComponent);
    end

    if automaticRejection && numel(rejectComponent) > maxReject
        combinedScore = max(kurtosisZ, highFrequencyZ);
        [~, scoreOrder] = sort( ...
            combinedScore(rejectComponent), 'descend');
        rejectComponent = rejectComponent(scoreOrder(1:maxReject));
    end

    [outputData, info] = ...
        HyperEEG.MultiCH.core.PreprocessICAReconstruct( ...
        model, rejectComponent);
    info.method = "extended_runica_auto";

end

function [outputData, info] = asrRepair( ...
        data, sampleRate, options, channelInfo)
%ASRREPAIR 调用clean_rawdata的ASR核心修复高振幅瞬态。
%   本实现关闭坏导删除和最终窗口删除，仅使用Burst修复并强制保持
%   原样本数，以保护多人数据的公共时间轴。直接调用clean_asr，避免
%   某些不完整插件安装中的clean_artifacts缺少BCILAB辅助函数。

    if exist('clean_asr', 'file') ~= 2
        error("未找到clean_asr，请在EEGLAB中安装并加载" + ...
            "clean_rawdata插件。");
    end

    [filledData, missingMask] = ...
        HyperEEG.MultiCH.core.PreprocessFillMissing(data);
    usableChannel = ~all(missingMask, 2);

    if sum(usableChannel) < 2
        error("ASR至少需要两个有效通道。");
    end

    if exist('eeg_emptyset', 'file') == 2
        asrEEG = eeg_emptyset();
    else
        asrEEG = struct();
    end

    asrEEG.data = filledData(usableChannel, :);
    asrEEG.srate = sampleRate;
    asrEEG.nbchan = size(asrEEG.data, 1);
    asrEEG.pnts = size(asrEEG.data, 2);
    asrEEG.trials = 1;
    asrEEG.xmin = 0;
    asrEEG.xmax = (asrEEG.pnts - 1) / sampleRate;
    asrEEG.times = (0:(asrEEG.pnts - 1)) / sampleRate * 1000;

    if ~isempty(channelInfo) && numel(channelInfo) == size(data, 1)
        asrEEG.chanlocs = channelInfo(usableChannel);
    end

    if exist('eeg_checkset', 'file') == 2
        asrEEG = eeg_checkset(asrEEG);
    end

    % 坏导、漂移和坏段已由前序步骤处理。robust方法又先修复极端瞬态，
    % 因此使用当前完整数据进行ASR校准，可避免clean_windows再次删除数据，
    % 同时绕开clean_artifacts对缺失BCILAB参数工具的依赖。
    cleanedEEG = clean_asr(asrEEG, ...
        options.asrBurstCriterion, ...  % StandardDevCutoff
        [], ...                         % WindowLength
        [], ...                         % BlockSize
        [], ...                         % MaxDimensions
        'off', ...                      % 使用完整数据校准
        'off', ...                      % 不筛校准窗
        'off', ...                      % 不筛校准窗
        false, ...                      % UseGPU
        false, ...                      % UseRiemannian
        options.asrMaxMemoryMB);

    if size(cleanedEEG.data, 2) ~= size(data, 2)
        error("ASR输出长度发生变化，已停止以保护公共时间轴。");
    end

    outputData = double(data);
    outputData(usableChannel, :) = double(cleanedEEG.data);
    outputData(missingMask) = NaN;

    info.method = "clean_rawdata_clean_asr";
    info.burstCriterion = options.asrBurstCriterion;
    info.maxMemoryMB = options.asrMaxMemoryMB;
    info.calibration = "entire_input_after_previous_methods";
    info.outputSamples = size(outputData, 2);

end

function zScore = robustZ(values)
%ROBUSTZ 使用中位数和MAD计算稳健Z分数，减少极端值对尺度的影响。

    centerValue = median(values);
    scaleValue = median(abs(values - centerValue));
    scaleValue = max(scaleValue, max(abs(centerValue), 1) * 1e-12);
    zScore = 0.67448975 * (values - centerValue) / scaleValue;

end

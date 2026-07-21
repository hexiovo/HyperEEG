function [outputData, info] = ...
        PreprocessReference(data, method, referenceChannels)
%PREPROCESSREFERENCE 按指定通道计算并减去重参考信号。
%   method支持median、average、channel和none。重参考是可选坐标变换，
%   并不等同于伪迹去除；referenceChannels为空时使用全部数据通道。

    method = lower(string(method));
    data = double(data);
    nChannel = size(data, 1);

    if isempty(referenceChannels)
        referenceChannels = 1:nChannel;
    end

    % 单通道减去自身会得到全零，因此默认参考策略必须安全跳过。
    if nChannel == 1 && any(strcmp(method, ["median", "average"]))
        outputData = data;
        info.method = method;
        info.referenceChannels = referenceChannels;
        info.applied = false;
        info.reason = "single_channel";
        return;
    end

    validateattributes(referenceChannels, {'numeric'}, ...
        {'vector', 'integer', '>=', 1, '<=', nChannel});

    switch method
        case "average"
            referenceSignal = mean( ...
                data(referenceChannels, :), 1, 'omitnan');
        case "median"
            referenceSignal = median( ...
                data(referenceChannels, :), 1, 'omitnan');
        case "channel"
            referenceSignal = mean( ...
                data(referenceChannels, :), 1, 'omitnan');
        case "none"
            outputData = data;
            info.method = method;
            info.referenceChannels = referenceChannels;
            return;
        otherwise
            error("重参考method必须为median、average、channel或none。");
    end

    % 某一时刻全部参考通道均为NaN时，不改变该时刻其它通道。
    referenceSignal(~isfinite(referenceSignal)) = 0;
    outputData = data - referenceSignal;
    info.method = method;
    info.referenceChannels = referenceChannels;
    info.applied = true;
    info.reason = "";

end

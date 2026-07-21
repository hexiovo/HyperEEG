function [EEGdata, info] = DataPreprocess_ArtifactAuto(EEGdata, options)
%DATAPREPROCESS_ARTIFACTAUTO 顺序执行一个或多个自动伪迹算法。
%   options.methods可为文本或文本数组。多方法会依次修改前一方法的输出，
%   因此不应仅因为“方法更多”就盲目串联。

    methods = normalizeMethods(options.methods);
    sampleRate = HyperEEG.MultiCH.core.PreprocessSampleRate(EEGdata);
    channelInfo = [];

    if isfield(EEGdata, "etc") && ...
            isfield(EEGdata.etc, "channel") && ...
            isfield(EEGdata.etc.channel, "info")
        channelInfo = EEGdata.etc.channel.info;
    end

    methodResults = cell(1, numel(methods));

    % 每种方法的结果分开保存，便于在processing history中追溯。
    for imethod = 1:numel(methods)
        currentMethod = methods(imethod);
        [EEGdata.data, methodResults{imethod}] = ...
            HyperEEG.MultiCH.core.PreprocessArtifact( ...
            EEGdata.data, EEGdata.times, sampleRate, ...
            currentMethod, options, channelInfo);

        if ismember(currentMethod, ["robust", "asr"])
            EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                EEGdata, currentMethod, 1);
        elseif currentMethod == "ica"
            EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                EEGdata, ["ica", "ica_auto"], 1);
        end
    end

    EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
        EEGdata, "preprocess_auto", 1);

    info.methods = methods;
    info.results = methodResults;

end

function methods = normalizeMethods(methods)
%NORMALIZEMETHODS 将char、cellstr或string统一为小写行向string数组。

    if iscellstr(methods) %#ok<ISCLSTR>
        methods = string(methods);
    elseif ischar(methods)
        methods = string(methods);
    end

    methods = lower(methods(:)');

end

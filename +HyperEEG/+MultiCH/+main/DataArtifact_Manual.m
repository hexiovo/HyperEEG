function [outsegment, cancelbool, excludeFileBool] = ...
        DataArtifact_Manual(EEGdata, currentfilename)
%DATAARTIFACT_MANUAL 收集并合并人工坏段/坏导标记。
%   只返回标记，不修改EEGdata。excludeFileBool=1表示channel=0覆盖
%   整份数据，Pipeline应排除该文件。取消与确认无标记是不同状态。

    excludeFileBool = 0;

    if nargin < 2 || isempty(currentfilename)
        currentfilename = "EEGdata.mat";
    end

    [outsegment, cancelbool] = ...
        HyperEEG.MultiCH.main.SegmentEditor( ...
        EEGdata, string(currentfilename));

    if cancelbool == 1
        outsegment = [];
        return;
    end

    % 同一通道重叠或相邻区间在保存前合并，减少重复处理。
    if isempty(outsegment)
        outsegment = struct('channel', {}, 'intervals', {});
    else
        mergedSegment = HyperEEG.MultiCH.misc.Segmentmerge(outsegment);
        outsegment = struct('channel', {}, 'intervals', {});

        for isegment = 1:numel(mergedSegment)
            outsegment(isegment).channel = ...
                str2double(mergedSegment(isegment).name);
            outsegment(isegment).intervals = ...
                mergedSegment(isegment).intervals;
        end

        excludeFileBool = ...
            HyperEEG.MultiCH.core.ArtifactIsWholeFileExcluded( ...
            outsegment, EEGdata.times);
    end

end

function [outsegment, emptybool] = DataArtifact_Auto(EEGdata, options)
%DATAARTIFACT_AUTO 自动识别需要全局排除的坏时间段。
%   本函数只返回channel=0标记，不修改数据；实际切割由Pipeline统一完成。

    if nargin < 2
        options = struct();
    end

    badIntervals = ...
        HyperEEG.MultiCH.core.ArtifactDetectByWindow(EEGdata, options);

    outsegment = struct('channel', {}, 'intervals', {});
    emptybool = isempty(badIntervals);

    if ~emptybool
        % channel = 0表示所有通道共同排除该时间段
        outsegment(1).channel = 0;
        outsegment(1).intervals = badIntervals;
    end

end

function DataQualitySummary_test
%DATAQUALITYSUMMARY_TEST 使用含时间缺口和整条坏导的合成数据验证比例。

    EEGdata.srate = 10;
    EEGdata.times = [0, 100, 200, 300, 500, 600, 700, 800];
    EEGdata.data = [1, 1, 1, 1, 1, NaN, 1, 1; ...
        NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN];

    [EEGdata, qualityInfo] = ...
        HyperEEG.MultiCH.core.DataQualitySummary(EEGdata);

    assert(isequal(qualityInfo.badchannel, 2));
    assert(isequal(qualityInfo.channelrate(:, 1), {'ch1'; 'ch2'}));
    assert(abs(qualityInfo.channelrate{1, 2} - 7 / 9) < 1e-12);
    assert(qualityInfo.channelrate{2, 2} == 0);
    assert(abs(qualityInfo.totalEffectiveRate - 7 / 18) < 1e-12);
    assert(~isfield(qualityInfo, 'channelrateText'));
    assert(~isfield(qualityInfo, 'rate'));
    assert(~isfield(EEGdata, 'badchannel'));
    assert(~isfield(EEGdata, 'channelrate'));
    assert(~isfield(EEGdata, 'channelrateText'));
    assert(~isfield(EEGdata, 'rate'));
    assert(EEGdata.Process.quality_summary == 1);
    fprintf('DATA_QUALITY_SUMMARY_TEST_OK\n');

end

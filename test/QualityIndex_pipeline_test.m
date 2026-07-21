function QualityIndex_pipeline_test
%QUALITYINDEX_PIPELINE_TEST 使用现有8CH目录验证最终质量汇总Pipeline。

    rawDir = 'I:\HyperEEG\data\脑电数据\8CH\raw';
    segmentDir = 'I:\HyperEEG\data\脑电数据\8CH\spilt';
    artifactDir = 'I:\HyperEEG\data\脑电数据\8CH\artifact';
    cleanDir = 'I:\HyperEEG\data\脑电数据\8CH\clean';

    [qualityTable, updatedFiles] = ...
        HyperEEG.MultiCH.pipeline.QualityIndex_pipeline( ...
        rawDir, segmentDir, artifactDir, cleanDir, "off");

    assert(height(qualityTable) == 18);
    assert(sum(qualityTable.isValid) == 13);
    assert(numel(updatedFiles) == 13);
    assert(qualityTable.deletionReason(qualityTable.recordId == "009") == ...
        "预处理阶段删除");
    assert(qualityTable.deletionReason(qualityTable.recordId == "011") == ...
        "坏段处理阶段删除");
    assert(all(qualityTable.deletionReason(ismember( ...
        qualityTable.recordId, ["013", "014", "015"])) == ...
        "数据切分阶段删除"));

    firstClean = load(fullfile(cleanDir, '001_video_clean.mat'), 'EEGdata');
    assert(isfield(firstClean.EEGdata, 'quality'));
    assert(iscell(firstClean.EEGdata.quality.channelrate));
    assert(size(firstClean.EEGdata.quality.channelrate, 2) == 2);
    assert(isfield(firstClean.EEGdata.quality, 'totalEffectiveRate'));
    assert(~isfield(firstClean.EEGdata.quality, 'channelrateText'));
    assert(~isfield(firstClean.EEGdata, 'badchannel'));
    assert(~isfield(firstClean.EEGdata, 'channelrate'));
    assert(~isfield(firstClean.EEGdata, 'channelrateText'));
    assert(~isfield(firstClean.EEGdata, 'rate'));
    fprintf('QUALITY_INDEX_PIPELINE_TEST_OK valid=13 invalid=5 updated=13\n');

end

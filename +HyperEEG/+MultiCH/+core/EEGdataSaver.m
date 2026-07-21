function EEGdata = EEGdataSaver(EEGdata,BDFdata)
%EEGDATASAVER 将BDF/EEGLAB元数据写入项目EEGdata结构。
%   集中维护开始时间、EEGLAB版本、通道信息和原始采样率字段。
    % 首次创建时预置全部流程状态为0；读取旧数据时只补齐缺失字段。
    EEGdata = HyperEEG.MultiCH.core.ProcessStatus(EEGdata);
    EEGdata.etc.starttime = BDFdata.etc.T0;
    EEGdata.etc.eeglabvers = BDFdata.etc.eeglabvers;
    EEGdata.etc.channel.num = BDFdata.nbchan;
    EEGdata.etc.channel.info = BDFdata.chanlocs;

    EEGdata.etc.samplerate.raw = BDFdata.srate;
end

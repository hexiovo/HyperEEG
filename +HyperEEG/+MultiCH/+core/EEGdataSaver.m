function EEGdata = EEGdataSaver(EEGdata,BDFdata)
    EEGdata.etc.starttime = BDFdata.etc.T0;
    EEGdata.etc.eeglabvers = BDFdata.etc.eeglabvers;
    EEGdata.etc.channel.num = BDFdata.nbchan;
    EEGdata.etc.channel.info = BDFdata.chanlocs;

    EEGdata.etc.samplerate.raw = BDFdata.srate;
end
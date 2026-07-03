function Artifact_pipeline(inputDir,outputDir)
    
    files = HyperEEG.MultiCH.misc.getFiles(inputDir,'mat');

    if isempty(files)
        warning("未找到任何文件。");
        return;
    end

    idx = ~strcmp({files.name}, 'segmentinfo.mat');
    segmentfiles = files(idx);
    
    for ifile = 1:length(segmentfiles)

        segmentfiles(i);
    end

end
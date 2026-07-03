function [outsegment, emptybool] = DataArtifact_Manual(filepath)
    
    [~, name, ext] = fileparts(filepath);
    name_data = erase(name, "_segment");
    if ~strcmpi(ext, ".mat")
        warning("文件不是MAT文件：%s", filepath);
        return;
    end

    try
        cdata = load(filepath);
    catch ME
        warning("读取MAT文件失败：%s\n%s", filepath, ME.message);
        return;
    end
    
    if ~isfield(cdata, "EEGdata")
        warning("MAT文件中不存在变量 EEGdata：%s", filepath);
        return;
    end
    
    EEGdata = cdata.EEGdata;

    [outsegment, emptybool] = HyperEEG.MultiCH.main.SegmentEditor(EEGdata,name_data+ext);
    
    if emptybool == 1 && ~isempty(outsegment)
        outsegment = HyperEEG.MultiCH.misc.Segmentmerge(outsegment);
    end


end
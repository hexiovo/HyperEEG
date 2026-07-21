function [updatedFiles, failedFiles] = BackfillProcessStatus( ...
        inputDir, dataStage)
%BACKFILLPROCESSSTATUS 为历史MAT结果补写EEGdata.Process状态。
%   dataStage为"segment"或"artifact"。函数只处理对应后缀文件，
%   先复制到同目录临时文件、补写并验证，再替换原文件；其它变量保留。

    if ~exist(inputDir, 'dir')
        error("inputDir不存在：%s", inputDir);
    end

    dataStage = lower(string(dataStage));

    switch dataStage
        case "segment"
            fileSuffix = "_segment.mat";
            completedSteps = ["bdf_import", "marker_extract", ...
                "marker_auto", "marker_manual", "segment"];
        case "artifact"
            fileSuffix = "_artifact.mat";
            completedSteps = ["bdf_import", "marker_extract", ...
                "marker_auto", "marker_manual", "segment", ...
                "artifact_auto", "artifact_manual", ...
                "artifact_segment", "artifact_complete"];
        otherwise
            error("dataStage必须为segment或artifact。");
    end

    allFiles = HyperEEG.MultiCH.misc.getFiles(inputDir, 'mat');
    targetFiles = allFiles(endsWith( ...
        allFiles, fileSuffix, 'IgnoreCase', true));
    updatedFiles = strings(0, 1);
    failedFiles = strings(0, 1);

    for ifile = 1:numel(targetFiles)
        filepath = string(targetFiles(ifile));
        temporaryPath = string(tempname(fileparts(filepath))) + ".mat";

        try
            loadedData = load(char(filepath), 'EEGdata');

            if ~isfield(loadedData, 'EEGdata')
                error("MAT文件中不存在EEGdata变量。");
            end

            EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                loadedData.EEGdata);
            EEGdata = HyperEEG.MultiCH.core.ProcessStatus( ...
                EEGdata, completedSteps, 1);

            % 在原文件副本上append，只替换EEGdata并保留可能存在的其它变量。
            [copySucceeded, copyMessage] = copyfile( ...
                char(filepath), char(temporaryPath));

            if ~copySucceeded
                error("创建临时副本失败：%s", copyMessage);
            end

            save(char(temporaryPath), 'EEGdata', '-append');
            validationData = load(char(temporaryPath), 'EEGdata');

            for istep = 1:numel(completedSteps)
                currentStep = char(completedSteps(istep));

                if validationData.EEGdata.Process.(currentStep) ~= 1
                    error("临时文件Process.%s验证失败。", currentStep);
                end
            end

            [moveSucceeded, moveMessage] = movefile( ...
                char(temporaryPath), char(filepath), 'f');

            if ~moveSucceeded
                error("替换原文件失败：%s", moveMessage);
            end

            updatedFiles(end + 1, 1) = filepath; %#ok<AGROW>
            fprintf("已补写Process：%s\n", filepath);
        catch ME
            failedFiles(end + 1, 1) = filepath; %#ok<AGROW>
            warning("Process补写失败：%s\n%s", filepath, ME.message);

            if isfile(temporaryPath)
                delete(char(temporaryPath));
            end
        end
    end

end

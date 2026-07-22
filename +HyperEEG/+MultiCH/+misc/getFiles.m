function filePaths = getFiles(rootPath, ext)
%GETFILES 递归获取指定后缀文件（string版本，不使用cell）
%
% filePaths = getFiles(rootPath, ext)
%
% 输出:
%   filePaths : string数组，每个元素为完整路径

    rootPath = string(rootPath);
    ext = string(ext);

    if ~isscalar(rootPath) || strlength(rootPath) == 0
        error("rootPath必须为非空文本标量。");
    end

    if ~isscalar(ext) || strlength(ext) == 0
        error("ext必须为非空文本标量。");
    end

    if ~startsWith(ext, ".")
        ext = "." + ext;
    end

    searchPattern = fullfile(rootPath, "**", "*" + ext);
    % MATLAB R2023a的dir在部分环境中不接受由混合文本拼接产生的
    % string数组；边界统一转为char标量。
    files = dir(char(searchPattern));

    filePaths = strings(length(files), 1);

    for i = 1:length(files)
        filePaths(i) = fullfile( ...
            files(i).folder, ...
            files(i).name);
    end
end

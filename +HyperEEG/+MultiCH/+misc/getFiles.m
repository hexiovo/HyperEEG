function filePaths = getFiles(rootPath, ext)
%GETFILES 递归获取指定后缀文件（string版本，不使用cell）
%
% filePaths = getFiles(rootPath, ext)
%
% 输出:
%   filePaths : string数组，每个元素为完整路径

    if ext(1) ~= '.'
        ext = ['.' ext];
    end

    files = dir(fullfile(rootPath, '**', ['*' ext]));

    filePaths = strings(length(files), 1);

    for i = 1:length(files)
        filePaths(i) = fullfile( ...
            files(i).folder, ...
            files(i).name);
    end
end
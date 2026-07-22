function pathCleanup = TemporarilyRemoveBuiltinShadows(contextName)
%TEMPORARILYREMOVEBUILTINSHADOWS 临时移除覆盖MATLAB基础函数的外部目录。
%   返回onCleanup对象；对象销毁时恢复调用前的完整MATLAB路径。

    if nargin < 1 || strlength(string(contextName)) == 0
        contextName = "表格读取";
    end

    originalPath = path;
    pathCleanup = onCleanup(@() path(originalPath));
    protectedFunctions = ["contains.m", "narginchk.m", "isequaln.m"];
    shadowDirectories = strings(0, 1);
    matlabRootPath = lower(strrep(string(matlabroot), "\", "/")) + "/";
    pathDirectories = split(string(originalPath), string(pathsep));

    for idirectory = 1:numel(pathDirectories)
        currentDirectory = pathDirectories(idirectory);

        if strlength(currentDirectory) == 0
            continue;
        end

        normalizedPath = lower(strrep(currentDirectory, "\", "/"));

        if startsWith(normalizedPath, matlabRootPath)
            continue;
        end

        for ifunction = 1:numel(protectedFunctions)
            if isfile(fullfile(currentDirectory, ...
                    protectedFunctions(ifunction)))
                shadowDirectories(end + 1, 1) = currentDirectory; %#ok<AGROW>
                break;
            end
        end
    end

    shadowDirectories = unique(shadowDirectories);

    for idirectory = 1:numel(shadowDirectories)
        warning("TemporarilyRemoveBuiltinShadows:RemovedShadow", ...
            "%s期间临时移除覆盖MATLAB内置函数的目录：%s", ...
            contextName, shadowDirectories(idirectory));
        rmpath(char(shadowDirectories(idirectory)));
    end

end

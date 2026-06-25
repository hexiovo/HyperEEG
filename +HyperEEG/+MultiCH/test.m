inputDir = 'I:\HyperEEG\data\脑电数据\8CH';

files = HyperEEG.MultiCH.misc.getFiles(inputDir,'BDF');
nfiles = length(files);

%% 逐个读取
for i = 1:1

    filename = files(i);   % 直接就是完整路径

    fprintf('正在读取: %s\n', filename);

    EEG = HyperEEG.MultiCH.core.BDFreader(filename);

end
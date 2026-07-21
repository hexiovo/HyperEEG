function sampleRate = PreprocessSampleRate(EEGdata)
%PREPROCESSSAMPLERATE 从EEGdata中解析当前有效采样率（Hz）。
%   优先顺序为samplerate.clean、samplerate.raw、EEGdata.srate，最后
%   才根据毫秒时间轴估算。这样重采样后的步骤不会继续使用原始采样率。

    if ~isstruct(EEGdata) || ~isscalar(EEGdata)
        error("EEGdata必须为标量结构体。");
    end

    sampleRate = [];

    if isfield(EEGdata, "etc") && ...
            isfield(EEGdata.etc, "samplerate")
        samplerate = EEGdata.etc.samplerate;

        if isstruct(samplerate)
            if isfield(samplerate, "clean") && ...
                    ~isempty(samplerate.clean)
                sampleRate = samplerate.clean;
            elseif isfield(samplerate, "raw") && ...
                    ~isempty(samplerate.raw)
                sampleRate = samplerate.raw;
            end
        elseif isnumeric(samplerate)
            sampleRate = samplerate;
        end
    end

    if isempty(sampleRate) && isfield(EEGdata, "srate")
        sampleRate = EEGdata.srate;
    end

    % 兼容早期文件：缺少采样率字段时由EEGdata.times回推。
    if isempty(sampleRate) && isfield(EEGdata, "times") && ...
            numel(EEGdata.times) >= 2
        timeStep = diff(double(EEGdata.times(:)));
        timeStep = timeStep(isfinite(timeStep) & timeStep > 0);

        if ~isempty(timeStep)
            % 本项目EEGdata.times以毫秒为单位。
            sampleRate = 1000 / median(timeStep);
        end
    end

    if ~isnumeric(sampleRate) || ~isscalar(sampleRate) || ...
            ~isfinite(sampleRate) || sampleRate <= 0
        error("无法从EEGdata获取有效采样率。");
    end

    sampleRate = double(sampleRate);

end

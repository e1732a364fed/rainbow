local audio_stego = {}
local logger = require("rainbow.logger")
local utils = require("rainbow.utils")

-- 音频参数配置
local config = {
    sample_rate = 8000,      -- 采样率
    carrier_freq = 1000,     -- 载波频率
    frame_size = 32,         -- 每个字节的采样点数
    sync_size = 64,          -- 同步序列长度
    sync_amplitude = 0.9,    -- 同步序列振幅
    amplitude_step = 1 / 256 -- 振幅步进（256个级别）
}

-- 生成同步序列
local function generate_sync_sequence()
    local sequence = {}
    for i = 1, config.sync_size do
        sequence[i] = (i % 2 == 0) and config.sync_amplitude or -config.sync_amplitude
    end
    return sequence
end

-- 将字节值映射到振幅
local function byte_to_amplitude(byte)
    return (byte + 1) * config.amplitude_step
end

-- 将振幅映射回字节值
local function amplitude_to_byte(amplitude)
    local byte = math.floor(amplitude / config.amplitude_step - 0.5)
    return math.max(0, math.min(255, byte))
end

-- 生成音频波形数据
local function generate_audio_data(data)
    local samples = {}
    local phase = 0
    local time_step = 1 / config.sample_rate
    local sync_sequence = generate_sync_sequence()

    -- 添加同步序列
    for _, sync_value in ipairs(sync_sequence) do
        table.insert(samples, sync_value)
    end

    -- 编码数据
    for i = 1, #data do
        local byte = data:byte(i)
        local amplitude = byte_to_amplitude(byte)

        -- 生成一帧数据
        for j = 1, config.frame_size do
            local sample = amplitude * math.sin(2 * math.pi * config.carrier_freq * phase)
            table.insert(samples, sample)
            phase = phase + time_step
        end

        -- 在字节之间添加短暂的静音
        for j = 1, 4 do
            table.insert(samples, 0)
        end
    end

    return samples
end

-- 计算信号的峰值振幅
local function calculate_peak_amplitude(frame)
    local peak = 0
    for _, sample in ipairs(frame) do
        peak = math.max(peak, math.abs(sample))
    end
    return peak
end

-- 从音频波形中提取数据
local function extract_data(samples)
    local data = {}
    local sync_detected = false
    local pos = 1

    -- 寻找同步序列
    while pos <= #samples - config.sync_size do
        local match = true
        local sync_sequence = generate_sync_sequence()

        for i = 1, config.sync_size do
            local expected = sync_sequence[i]
            local actual = samples[pos + i - 1]
            -- 允许10%的误差
            if math.abs(math.abs(actual) - math.abs(expected)) > 0.1 * math.abs(expected) then
                match = false
                break
            end
        end

        if match then
            sync_detected = true
            pos = pos + config.sync_size
            break
        end
        pos = pos + 1
    end

    if not sync_detected then
        return nil
    end

    -- 解码数据
    local frame_size = config.frame_size + 4 -- 包括静音间隔
    while pos + config.frame_size <= #samples do
        local frame = {}
        for i = 1, config.frame_size do
            table.insert(frame, samples[pos + i - 1])
        end

        local amplitude = calculate_peak_amplitude(frame)
        if amplitude > config.amplitude_step / 2 then
            local byte = amplitude_to_byte(amplitude)
            table.insert(data, string.char(byte))
        end

        pos = pos + frame_size
    end

    return table.concat(data)
end

-- 编码函数
function audio_stego.encode(data)
    logger.debug("Encoding data using Web Audio API stego")

    if #data == 0 then
        return "<audio id=\"stego-audio\" style=\"display:none\"></audio>"
    end

    if #data > 1000 then
        logger.warn("Data too long, truncating to 1000 bytes")
        data = data:sub(1, 1000)
    end

    -- 生成音频波形
    local audio_data = generate_audio_data(data)

    -- 将音频数据转换为 Base64 字符串
    local encoded = utils.base64_encode(table.concat(audio_data, ","))

    -- 生成包含音频数据的 HTML5 音频元素
    return string.format([[
        <audio id="stego-audio" style="display:none">
            <source src="data:audio/wav;base64,%s" type="audio/wav">
        </audio>
    ]], encoded)
end

-- 解码函数
function audio_stego.decode(content)
    logger.debug("Decoding data from Web Audio API stego")

    if not content or content == "" then
        logger.warn("Empty audio content")
        return ""
    end

    if content:match("^%s*<audio[^>]*>%s*</audio>%s*$") then
        logger.debug("Empty audio element found")
        return ""
    end

    -- 提取 Base64 编码的音频数据
    local base64_data = content:match("base64,([^\"]+)")
    if not base64_data then
        logger.error("No audio data found in content")
        return nil
    end

    -- 解码 Base64 数据
    local decoded = utils.base64_decode(base64_data)
    if not decoded then
        logger.error("Failed to decode base64 audio data")
        return nil
    end

    -- 将解码后的数据转换为样本数组
    local samples = {}
    for sample in decoded:gmatch("[^,]+") do
        table.insert(samples, tonumber(sample))
    end

    if #samples == 0 then
        logger.error("No valid audio samples found")
        return nil
    end

    -- 从音频波形中提取数据
    local data = extract_data(samples)
    if not data then
        logger.error("Failed to extract data from audio samples")
        return nil
    end

    logger.info("Successfully decoded %d bytes from audio", #data)
    return data
end

return audio_stego

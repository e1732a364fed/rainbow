local stego = {}
local logger = require("rainbow.logger")

-- 基本 MIME 类型定义
local mime_types = {
    basic = {
        ["text/html"] = true,
        ["application/json"] = true,
        ["application/xml"] = true,
        ["audio/wav"] = true
    }
}

-- 检查是否为有效的 MIME 类型
function stego.is_valid_mime_type(mime_type)
    return mime_types.basic[mime_type] == true
end

-- 导入所有编码器
stego.css = require("rainbow.stego.css_stego")
stego.prism = require("rainbow.stego.prism_stego")
stego.font = require("rainbow.stego.font_stego")
stego.svg = require("rainbow.stego.svg_path_stego")
stego.html = require("rainbow.stego.html_stego")
stego.json = require("rainbow.stego.json_stego")
stego.xml = require("rainbow.stego.xml_stego")
stego.rss = require("rainbow.stego.rss_stego")
stego.audio = require("rainbow.stego.audio_stego")

-- MIME 类型编码器映射
-- 每个标准 MIME 类型对应一个编码器数组
local mime_encoders = {
    ["text/html"] = {
        stego.html,
        stego.prism,
        stego.font,
        stego.svg,
        stego.css
    },
    ["application/json"] = {
        stego.json
    },
    ["application/xml"] = {
        stego.xml,
        stego.rss
    },
    ["audio/wav"] = {
        stego.audio
    }
}

-- 从指定 MIME 类型的编码器列表中随机选择一个
local function get_random_encoder(mime_type)
    local encoders = mime_encoders[mime_type]
    if not encoders then return nil end
    return encoders[math.random(#encoders)]
end

-- 获取指定 MIME 类型的编码器列表（用于测试）
function stego.get_mime_encoders(mime_type)
    return mime_encoders[mime_type]
end

-- 获取随机 MIME 类型
function stego.get_random_mime_type()
    local mime_types = {}
    for mime_type, _ in pairs(mime_encoders) do
        table.insert(mime_types, mime_type)
    end
    return mime_types[math.random(#mime_types)]
end

-- 编码数据到指定 MIME 类型
function stego.encode_mime(data, mime_type)
    logger.debug("Encoding data with MIME type: %s", mime_type)
    local encoder = get_random_encoder(mime_type)
    if encoder then
        -- 生成编码器标识信息
        local encoder_index = 0
        local encoders = mime_encoders[mime_type]
        for i, e in ipairs(encoders) do
            if e == encoder then
                encoder_index = i
                break
            end
        end

        -- 将编码器索引转换为16进制（2字节）
        local encoder_id = string.format("%02x", encoder_index)
        -- 生成随机噪声（2字节）用于混淆
        local noise = string.format("%02x", math.random(0, 0xFF))
        -- 组合标识符（4字节）
        local identifier = encoder_id .. noise

        -- 将编码器标识和数据一起编码
        local result
        if mime_type == "text/html" then
            -- 在 HTML 注释中添加标识和数据
            result = encoder.encode(data)
            if result then
                -- 确保不会覆盖原始数据
                result = result:gsub("<!%-%-(.-)%-%->", "<!--" .. identifier .. "%1-->", 1)
            end
        elseif mime_type == "application/json" then
            -- 在 JSON 开头添加标识
            result = encoder.encode(data)
            if result then
                result = identifier .. result
            end
        elseif mime_type == "application/xml" then
            -- 在 XML 版本信息中隐藏标识
            result = encoder.encode(data)
            if result then
                result = result:gsub('<%?xml[^?]*%?>', '<?xml version="1.' .. identifier .. '"?>', 1)
            end
        elseif mime_type == "audio/wav" then
            -- 在音频文件的元数据中隐藏标识
            result = encoder.encode(data)
            if result then
                result = result:gsub('(INAM)', identifier .. '%1', 1)
            end
        end

        if result then
            logger.debug("Successfully encoded %d bytes using %s (ID: %s)",
                #result, encoder.name, encoder_id)
            return result
        end
        logger.warn("Failed to encode data with %s", mime_type)
    end
    return nil
end

-- 从指定 MIME 类型解码数据
function stego.decode_mime(content, mime_type)
    logger.debug("Decoding data with MIME type: %s", mime_type)

    -- 尝试从内容中提取编码器标识
    local identifier
    if mime_type == "text/html" then
        identifier = content:match("<!%-%-(%x%x%x%x)%-%-")
    elseif mime_type == "application/json" then
        identifier = content:match("^(%x%x%x%x)")
        content = content:sub(5) -- 移除标识符
    elseif mime_type == "application/xml" then
        identifier = content:match('version="1%.(%x%x%x%x)"')
    elseif mime_type == "audio/wav" then
        identifier = content:match('(%x%x%x%x)INAM')
    end

    local encoders = mime_encoders[mime_type]
    if encoders then
        -- 如果找到标识符，优先使用对应的编码器
        if identifier then
            -- 提取编码器索引（前2字节）
            local encoder_id = tonumber(identifier:sub(1, 2), 16)
            if encoder_id and encoder_id > 0 and encoder_id <= #encoders then
                local target_encoder = encoders[encoder_id]
                logger.debug("Using identified encoder: %s (ID: %02x)", target_encoder.name, encoder_id)
                local result = target_encoder.decode(content)
                if result then
                    logger.debug("Successfully decoded using identified encoder: %s", target_encoder.name)
                    return result
                end
            end
        end

        -- 如果没有找到标识符或解码失败，尝试所有编码器
        for _, encoder in ipairs(encoders) do
            logger.debug("Trying encoder: %s", encoder.name)
            local result = encoder.decode(content)
            if result and result ~= "" then
                logger.debug("Successfully decoded %d bytes using %s", #result, encoder.name)
                return result
            end
        end
        logger.warn("All decoders failed for MIME type: %s", mime_type)
    else
        logger.warn("No decoder found for MIME type: %s", mime_type)
    end
    return nil
end

-- 自动生成编码器名称到实例的映射
local encoder_name_map = {}
for name, encoder in pairs(stego) do
    -- 只包含实际的编码器模块（具有 encode 和 decode 方法的模块）
    if type(encoder) == "table" and encoder.encode and encoder.decode then
        encoder_name_map[name] = encoder
    end
end

-- 通过编码器名称进行编码
function stego.encode_by_encoder(data, encoder_name)
    logger.debug("Encoding data with encoder: %s", encoder_name)
    local encoder = encoder_name_map[encoder_name]
    if not encoder then
        logger.warn("Encoder not found: %s", encoder_name)
        return nil
    end

    local result = encoder.encode(data)
    if result then
        logger.debug("Successfully encoded %d bytes using %s", #result, encoder_name)
        return result
    end
    logger.warn("Failed to encode data with %s", encoder_name)
    return nil
end

return stego

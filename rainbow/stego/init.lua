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
        local result = encoder.encode(data)
        if result then
            logger.debug("Successfully encoded %d bytes using %s", #result, encoder.name or "unknown encoder")
            -- 返回编码器名称而不是对象
            return result, encoder.name
        end
        logger.warn("Failed to encode data with %s", mime_type)
    else
        logger.warn("No encoder found for MIME type: %s", mime_type)
    end
    return nil
end

-- 从指定 MIME 类型解码数据
function stego.decode_mime(content, mime_type, preferred_encoder)
    logger.debug("Decoding data with MIME type: %s", mime_type)
    if preferred_encoder then
        logger.debug("Using preferred encoder: %s", preferred_encoder)
    end

    -- 尝试该 MIME 类型下的所有解码器
    local encoders = mime_encoders[mime_type]
    if encoders then
        -- 如果有首选编码器，先尝试它
        if preferred_encoder then
            for _, encoder in ipairs(encoders) do
                if encoder.name == preferred_encoder then
                    local result = encoder.decode(content)
                    if result then
                        logger.debug("Successfully decoded %d bytes using preferred encoder", #result)
                        return result
                    end
                end
            end
        end

        -- 如果首选编码器失败或不存在，尝试其他编码器
        for _, encoder in ipairs(encoders) do
            if not preferred_encoder or encoder.name ~= preferred_encoder then
                local result = encoder.decode(content)
                if result then
                    logger.debug("Successfully decoded %d bytes using %s", #result, encoder.name or "unknown encoder")
                    return result
                end
            end
        end
        logger.warn("All decoders failed for MIME type: %s", mime_type)
    else
        logger.warn("No decoder found for MIME type: %s", mime_type)
    end
    return nil
end

return stego

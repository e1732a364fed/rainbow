local stego = {}
local logger = require("rainbow.logger")

-- 基本 MIME 类型定义
local mime_types = {
    basic = {
        ["text/html"] = true,
        ["application/json"] = true,
        ["application/xml"] = true
    }
}

-- 检查是否为有效的 MIME 类型
local function is_valid_mime_type(mime_type)
    return mime_types.basic[mime_type]
end

-- 导入所有编码器
stego.css = require("rainbow.stego.css_stego").css_encoder
stego.prism = require("rainbow.stego.prism_stego")
stego.font = require("rainbow.stego.font_stego").font_encoder
stego.svg = require("rainbow.stego.svg_path_stego").svg_encoder
stego.html = require("rainbow.stego.html_stego")
stego.json = require("rainbow.stego.json_stego")
stego.xml = require("rainbow.stego.xml_stego")
stego.rss = require("rainbow.stego.rss_stego")

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
    }
}

-- 从指定 MIME 类型的编码器列表中随机选择一个
local function get_random_encoder(mime_type)
    local encoders = mime_encoders[mime_type]
    if not encoders then return nil end
    return encoders[math.random(#encoders)]
end

-- Base64 编码函数
function stego.base64_encode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r;
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
        return b:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

-- Base64 解码函数
function stego.base64_decode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^' .. b .. '=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r, f = '', (b:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
        return string.char(c)
    end))
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
            logger.debug("Successfully encoded %d bytes", #result)
            return result
        end
        logger.warn("Failed to encode data with %s", mime_type)
    else
        logger.warn("No encoder found for MIME type: %s", mime_type)
    end
    return nil
end

-- 从指定 MIME 类型解码数据
function stego.decode_mime(content, mime_type)
    logger.debug("Decoding data with MIME type: %s", mime_type)
    -- 尝试该 MIME 类型下的所有解码器
    local encoders = mime_encoders[mime_type]
    if encoders then
        for _, encoder in ipairs(encoders) do
            local result = encoder.decode(content)
            if result then
                logger.debug("Successfully decoded %d bytes", #result)
                return result
            end
        end
        logger.warn("All decoders failed for MIME type: %s", mime_type)
    else
        logger.warn("No decoder found for MIME type: %s", mime_type)
    end
    return nil
end

return stego

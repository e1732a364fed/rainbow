local mime = {}
local logger = require("rainbow.logger")

-- HTML 隐写编码器
local html_encoder = {}

function html_encoder.encode(data)
    -- 创建一个基础的 HTML 结构
    local html_template = [[
<!DOCTYPE html>
<html>
<head>
    <title>%s</title>
    <style>
        .content { font-family: Arial; line-height: 1.6; }
        .%s { display: none; }
    </style>
</head>
<body>
    <div class="content">
        %s
        <div class="%s">%s</div>
    </div>
</body>
</html>
]]

    -- 生成随机的类名来存储数据
    local random_class = "c" .. tostring(math.random(10000, 99999))

    -- 生成随机的页面标题
    local titles = {
        "Welcome to Our Website",
        "About Us",
        "Latest News",
        "Contact Information"
    }
    local random_title = titles[math.random(#titles)]

    -- 生成随机的可见文本内容
    local visible_contents = {
        "Welcome to our website. We provide high-quality services.",
        "Our team is dedicated to excellence in everything we do.",
        "Stay updated with our latest news and developments."
    }
    local visible_content = visible_contents[math.random(#visible_contents)]

    -- Base64 编码数据
    local b64_data = mime.base64_encode(data)

    return string.format(html_template,
        random_title,
        random_class,
        visible_content,
        random_class,
        b64_data
    )
end

function html_encoder.decode(html_content)
    -- 提取隐藏的 div 中的内容
    local pattern = 'class="c%d+">(.-)</div>'
    local encoded_data = string.match(html_content, pattern)
    if encoded_data then
        return mime.base64_decode(encoded_data)
    end
    return nil
end

-- JSON 隐写编码器
local json_encoder = {}

function json_encoder.encode(data)
    -- 创建一个看起来像正常的 JSON 结构
    local json_template = [[
{
    "timestamp": %d,
    "version": "1.0",
    "status": "success",
    "data": {
        "id": "%s",
        "type": "article",
        "attributes": {
            "title": "%s",
            "content": "%s",
            "metadata": "%s"
        }
    }
}]]

    -- 生成随机 ID
    local random_id = string.format("%x%x",
        math.random(0, 0xFFFFFF),
        math.random(0, 0xFFFFFF))

    -- 生成随机标题
    local titles = {
        "Latest Updates",
        "System Status",
        "User Information"
    }
    local random_title = titles[math.random(#titles)]

    -- 生成随机可见内容
    local contents = {
        "Everything is working as expected.",
        "System performance is optimal.",
        "All services are operational."
    }
    local random_content = contents[math.random(#contents)]

    -- Base64 编码实际数据
    local encoded_data = mime.base64_encode(data)

    return string.format(json_template,
        os.time(),
        random_id,
        random_title,
        random_content,
        encoded_data
    )
end

function json_encoder.decode(json_content)
    -- 提取 metadata 字段中的数据
    local pattern = '"metadata":%s*"([^"]+)"'
    local encoded_data = string.match(json_content, pattern)
    if encoded_data then
        return mime.base64_decode(encoded_data)
    end
    return nil
end

-- Base64 编码/解码工具函数
function mime.base64_encode(data)
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

function mime.base64_decode(data)
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

-- MIME 类型注册表
mime.encoders = {
    ["text/html"] = html_encoder,
    ["application/json"] = json_encoder,
    ["text/html+css"] = require("rainbow.css_stego").css_encoder,
    ["text/html+prism"] = require("rainbow.prism_stego")
}

-- 获取随机 MIME 类型
function mime.get_random_mime_type()
    local mime_types = {}
    for k, _ in pairs(mime.encoders) do
        table.insert(mime_types, k)
    end
    return mime_types[math.random(#mime_types)]
end

-- 编码数据到指定 MIME 类型
function mime.encode(data, mime_type)
    logger.debug("Encoding data with MIME type: %s", mime_type)
    local encoder = mime.encoders[mime_type]
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
function mime.decode(content, mime_type)
    logger.debug("Decoding data with MIME type: %s", mime_type)
    local encoder = mime.encoders[mime_type]
    if encoder then
        local result = encoder.decode(content)
        if result then
            logger.debug("Successfully decoded %d bytes", #result)
            return result
        end
        logger.warn("Failed to decode data with %s", mime_type)
    else
        logger.warn("No decoder found for MIME type: %s", mime_type)
    end
    return nil
end

return mime

local mime_types = {}
local logger = require("rainbow.logger")

-- SVG 隐写编码器
local svg_encoder = {}

function svg_encoder.encode(data)
    logger.debug("Encoding data using SVG steganography")
    -- 创建一个基础的 SVG 结构，使用 viewBox 和 path 数据来隐藏信息
    local svg_template = [[
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
        <style>
            .%s { opacity: 0.01; }
        </style>
    </defs>
    <g class="%s">
        <path d="%s"/>
    </g>
    <circle cx="50" cy="50" r="40" stroke="black" stroke-width="2" fill="none"/>
</svg>
]]

    -- 将数据编码为 SVG path 命令
    local function encode_to_path(str)
        local path = "M0,0 "
        for i = 1, #str do
            local byte = str:byte(i)
            -- 使用字符的 ASCII 值来生成看似合理的路径数据
            path = path .. string.format("l%d,%d ", byte % 10, byte % 8)
        end
        return path
    end

    local random_class = "c" .. tostring(math.random(10000, 99999))
    local encoded_path = encode_to_path(data)

    logger.info("Generated SVG with path data length: %d", #encoded_path)
    return string.format(svg_template, random_class, random_class, encoded_path)
end

function svg_encoder.decode(svg_content)
    logger.debug("Decoding SVG steganography")
    -- 从 path 数据中提取隐藏信息
    local path_data = svg_content:match('path%s+d="([^"]+)"')
    if not path_data then
        logger.warn("No path data found in SVG")
        return nil
    end

    local result = {}
    -- 解析路径命令中的数值对
    for x, y in path_data:gmatch("l(%d+),(%d+)") do
        -- 根据坐标值重建原始字节
        local byte = tonumber(x) * 8 + tonumber(y)
        if byte >= 32 and byte <= 126 then -- 可打印字符范围
            table.insert(result, string.char(byte))
        end
    end

    if #result > 0 then
        logger.info("Successfully decoded %d bytes from SVG", #result)
    end
    return table.concat(result)
end

-- XML 隐写编码器
local xml_encoder = {}

function xml_encoder.encode(data)
    logger.debug("Encoding data using XML steganography")
    -- 创建一个看起来像配置文件的 XML 结构
    local xml_template = [[
<?xml version="1.0" encoding="UTF-8"?>
<configuration timestamp="%d">
    <settings>
        <property name="%s" value="%s"/>
        <property name="theme" value="default"/>
        <property name="language" value="en"/>
    </settings>
    <data>%s</data>
</configuration>
]]

    -- 生成随机的属性名
    local random_prop = "prop_" .. tostring(math.random(1000, 9999))

    -- 生成随机的可见值
    local visible_values = {
        "enabled", "disabled", "auto", "manual", "default"
    }
    local random_value = visible_values[math.random(#visible_values)]

    -- Base64 编码数据并嵌入到 CDATA 部分
    local encoded_data = mime_types.base64_encode(data)
    local cdata = string.format("<![CDATA[%s]]>", encoded_data)

    logger.info("Generated XML with CDATA length: %d", #encoded_data)
    return string.format(xml_template,
        os.time(),
        random_prop,
        random_value,
        cdata
    )
end

function xml_encoder.decode(xml_content)
    logger.debug("Decoding XML steganography")
    -- 从 CDATA 部分提取 Base64 编码的数据
    local encoded_data = xml_content:match("<![CDATA[(.-)]]>")
    if not encoded_data then
        logger.warn("No CDATA section found in XML")
        return nil
    end
    local decoded_data = mime_types.base64_decode(encoded_data)
    if decoded_data then
        logger.info("Successfully decoded %d bytes from XML", #decoded_data)
    end
    return decoded_data
end

-- RSS Feed 隐写编码器
local rss_encoder = {}

function rss_encoder.encode(data)
    logger.debug("Encoding data using RSS steganography")
    -- 创建一个看起来像普通 RSS feed 的结构
    local rss_template = [[
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
    <channel>
        <title>%s</title>
        <description>%s</description>
        <link>https://example.com/feed</link>
        <lastBuildDate>%s</lastBuildDate>
        <item>
            <title>%s</title>
            <description>%s</description>
            <pubDate>%s</pubDate>
            <guid>%s</guid>
        </item>
    </channel>
</rss>
]]

    -- 生成随机的 RSS 内容
    local titles = {
        "Latest Updates", "Daily News", "Tech Blog",
        "Community Updates", "Product News"
    }

    local descriptions = {
        "Stay updated with our latest news and announcements.",
        "Check out our recent developments and updates.",
        "Important information for our community members."
    }

    -- 在 guid 中隐藏编码后的数据
    local encoded_data = mime_types.base64_encode(data)
    local guid = "tag:example.com," .. os.date("%Y") .. ":" .. encoded_data

    logger.info("Generated RSS feed with GUID length: %d", #encoded_data)
    return string.format(rss_template,
        titles[math.random(#titles)],
        descriptions[math.random(#descriptions)],
        os.date("!%a, %d %b %Y %H:%M:%S GMT"),
        titles[math.random(#titles)],
        descriptions[math.random(#descriptions)],
        os.date("!%a, %d %b %Y %H:%M:%S GMT"),
        guid
    )
end

function rss_encoder.decode(rss_content)
    logger.debug("Decoding RSS steganography")
    -- 从 guid 中提取编码的数据
    local encoded_data = rss_content:match("tag:example%.com,%d+:([^<]+)")
    if not encoded_data then
        logger.warn("No encoded data found in RSS GUID")
        return nil
    end
    local decoded_data = mime_types.base64_decode(encoded_data)
    if decoded_data then
        logger.info("Successfully decoded %d bytes from RSS", #decoded_data)
    end
    return decoded_data
end

-- 注册所有编码器
mime_types.encoders = {
    ["image/svg+xml"] = svg_encoder,
    ["application/xml"] = xml_encoder,
    ["application/rss+xml"] = rss_encoder
}

-- 从现有的 mime_encoder 模块导入 base64 函数
local mime = require("rainbow.mime_encoder")
mime_types.base64_encode = mime.base64_encode
mime_types.base64_decode = mime.base64_decode

-- 将新的编码器添加到现有的 MIME 编码器中
for mime_type, encoder in pairs(mime_types.encoders) do
    mime.encoders[mime_type] = encoder
end

return mime_types

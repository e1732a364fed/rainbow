local rss_stego = {}
local logger = require("rainbow.logger")
local utils = require("rainbow.utils")

-- RSS Feed 模板
local RSS_TEMPLATE = [[
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
    <title>Rainbow RSS Feed</title>
    <link>http://example.com/feed</link>
    <description>A steganographic RSS feed</description>
    <language>en-us</language>
    <pubDate>%s</pubDate>
    <lastBuildDate>%s</lastBuildDate>
    <docs>http://blogs.law.harvard.edu/tech/rss</docs>
    <generator>Rainbow RSS Generator</generator>
    <item>
        <title>Hidden Data</title>
        <link>http://example.com/item/1</link>
        <description>This item contains hidden data</description>
        <pubDate>%s</pubDate>
        <guid>%s</guid>
    </item>
</channel>
</rss>
]]

-- 生成 RFC822 格式的日期字符串
local function get_rfc822_date()
    return os.date("!%a, %d %b %Y %H:%M:%S GMT")
end

-- 编码函数
function rss_stego.encode(data)
    logger.debug("Encoding data using RSS stego")

    -- Base64 编码数据
    local encoded_data = utils.base64_encode(data)

    -- 获取当前时间
    local current_time = get_rfc822_date()

    -- 生成 RSS feed
    return string.format(RSS_TEMPLATE,
        current_time, -- pubDate
        current_time, -- lastBuildDate
        current_time, -- item pubDate
        encoded_data  -- guid (contains hidden data)
    )
end

-- 解码函数
function rss_stego.decode(content)
    logger.debug("Decoding data from RSS stego")

    -- 从 GUID 标签中提取数据
    local encoded_data = content:match("<guid>([^<]+)</guid>")
    if not encoded_data then
        logger.error("No GUID found in RSS content")
        return nil
    end

    -- Base64 解码数据
    local decoded = utils.base64_decode(encoded_data)
    if not decoded then
        logger.error("Failed to decode Base64 data from RSS")
        return nil
    end

    return decoded
end

return rss_stego

local rss_encoder = {}
local logger = require("rainbow.logger")
local mime = require("rainbow.stego.mime_manager")

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
    local encoded_data = mime.base64_encode(data)
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
        return ""
    end
    local decoded_data = mime.base64_decode(encoded_data)
    if decoded_data then
        logger.info("Successfully decoded %d bytes from RSS", #decoded_data)
    end
    return decoded_data
end

return rss_encoder

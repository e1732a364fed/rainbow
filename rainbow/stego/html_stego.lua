local html_encoder = {}
local logger = require("rainbow.logger")

-- 添加模块名称
html_encoder.name = "html"

function html_encoder.encode(data)
    logger.debug("Encoding data using HTML comment steganography")

    if #data == 0 then
        return [[<!DOCTYPE html><html><head></head><body></body></html>]]
    end

    -- 将数据编码为 HTML 注释，确保不添加额外的空格
    local encoded = string.format("<!--%s-->", data:gsub("%-%-", "&#45;&#45;"))

    -- 构建完整的 HTML 文档
    local template = [[
<!DOCTYPE html>
<html>
<head>
    <title>Page Information</title>
</head>
<body>
    <div class="content">%s
        <p>This page contains important information.</p>
    </div>
</body>
</html>]]

    logger.info("Generated HTML comment steganography with %d bytes", #data)
    return string.format(template, encoded)
end

function html_encoder.decode(html_content)
    logger.debug("Decoding HTML comment steganography")

    if not html_content or html_content == "" then
        return ""
    end

    -- 首先尝试提取带标识符的数据
    local data = html_content:match("<!%-%-[%x][%x][%x][%x](.-)%-%->")
    if not data then
        -- 如果没有找到带标识符的数据，尝试提取普通注释数据
        data = html_content:match("<!%-%-(.-)%-%->")
    end

    if data then
        -- 还原转义的注释标记
        data = data:gsub("&#45;&#45;", "--")
        logger.info("Successfully decoded %d bytes from HTML comments", #data)
        return data
    end

    logger.warn("No data found in HTML comments")
    return ""
end

return html_encoder

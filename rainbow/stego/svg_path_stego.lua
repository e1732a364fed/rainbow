local svg_encoder = {}
local logger = require("rainbow.logger")

-- 添加模块名称
svg_encoder.name = "svg_path"

function svg_encoder.encode(data)
    logger.debug("Encoding data using SVG path animation steganography")

    if #data == 0 then
        return [[<svg viewBox="0 0 200 200"></svg>]]
    end

    -- 将字节转换为路径动画
    local paths = {}
    for i = 1, #data do
        local byte = data:byte(i)
        local x = byte % 16 * 10
        local y = math.floor(byte / 16) * 10

        -- 创建基于字节值的贝塞尔曲线路径
        local path = string.format([[
            <path id="p%d" d="M %d,%d Q%d,%d %d,%d">
                <animate
                    attributeName="d"
                    dur="%d.%ds"
                    values="M %d,%d Q%d,%d %d,%d;
                           M %d,%d Q%d,%d %d,%d"
                    repeatCount="indefinite"/>
            </path>
        ]], i, x, y, x + 10, y + 10, x + 20, y,
            byte % 3 + 1, byte % 10,
            x, y, x + 10, y + 10, x + 20, y,
            x + 5, y + 5, x + 15, y + 15, x + 25, y + 5)

        table.insert(paths, path)
    end

    -- 构建完整的 SVG 文档
    local template = [[
<!DOCTYPE html>
<html>
<head>
    <title>Interactive Art</title>
    <style>
        svg { width: 100%%; height: 100vh; }
        path { stroke: #333; fill: none; stroke-width: 2; }
    </style>
</head>
<body>
    <svg viewBox="0 0 200 200">
        <defs>
            <filter id="blur">
                <feGaussianBlur stdDeviation="0.5"/>
            </filter>
        </defs>
        %s
    </svg>
</body>
</html>
]]

    logger.info("Generated SVG path animation with %d paths", #data)
    return string.format(template, table.concat(paths, "\n"))
end

function svg_encoder.decode(html_content)
    logger.debug("Decoding SVG path animation steganography")

    if not html_content or html_content == "" then
        return ""
    end

    local result = {}

    -- 提取所有路径数据，使用更精确的正则表达式
    for path_data in html_content:gmatch('<path[^>]+d="M%s*([^"]+)"') do
        -- 提取初始路径的坐标（忽略动画值）
        local x, y = path_data:match("(%d+),(%d+)")
        if x and y then
            x, y = tonumber(x), tonumber(y)
            -- 从坐标还原字节值
            local byte = (math.floor(y / 10) * 16) + math.floor(x / 10)
            table.insert(result, string.char(byte))
            logger.debug("Decoded coordinates (%d,%d) to byte: %d", x, y, byte)
        end
    end

    local decoded = table.concat(result)
    if #decoded > 0 then
        logger.info("Successfully decoded %d bytes from SVG paths", #decoded)
    else
        logger.warn("No data found in SVG paths")
    end

    return decoded
end

return svg_encoder

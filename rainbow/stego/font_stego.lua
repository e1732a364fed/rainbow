local font_encoder = {}
local logger = require("rainbow.logger")

function font_encoder.encode(data)
    logger.debug("Encoding data using font variation steganography")

    if #data == 0 then
        return [[<!DOCTYPE html><html><head></head><body></body></html>]]
    end

    -- 生成字体变体定义
    local variations = {}
    local chars = {}
    for i = 1, #data do
        local byte = data:byte(i)
        -- 修改字节值拆分方式
        local weight = math.floor(byte / 16) * 100 + 100 -- 100-1600 范围的字重
        local width = byte % 16 * 6                      -- 0-90 范围的宽度
        local slant = (byte % 4) * 5                     -- 0, 5, 10, 15 度倾斜

        -- 创建字体变体样式
        local style = string.format([[
            .v%d {
                font-variation-settings: 'wght' %d, 'wdth' %d, 'slnt' %d;
                font-family: 'Variable';
            }]], i, weight, width, slant)
        table.insert(variations, style)

        -- 创建带有类的字符元素
        table.insert(chars, string.format('<span class="v%d">O</span>', i))
    end

    -- 构建完整的 HTML 文档
    local template = [[
<!DOCTYPE html>
<html>
<head>
    <title>Typography Showcase</title>
    <style>
        @font-face {
            font-family: 'Variable';
            src: url('data:font/woff2;base64,d09GMgABAAA...') format('woff2');
            font-weight: 100 900;
            font-stretch: 25%% 151%%;
            font-style: oblique 0deg 15deg;
        }
        body {
            font-family: 'Variable', sans-serif;
            line-height: 1.5;
        }
        span {
            display: inline-block;
            margin: 0.1em;
        }
        %s
    </style>
</head>
<body>
    <div class="content">
        <h1>Typography Examples</h1>
        %s
        <p>Exploring variable fonts in modern web design.</p>
    </div>
</body>
</html>
]]

    logger.info("Generated font variation steganography with %d characters", #data)
    return string.format(template,
        table.concat(variations, "\n        "),
        table.concat(chars, "\n        "))
end

function font_encoder.decode(html_content)
    logger.debug("Decoding font variation steganography")

    if not html_content or html_content == "" then
        return ""
    end

    local result = {}

    -- 提取所有字体变体设置
    local pattern = "font%-variation%-settings:%s*'wght'%s*(%d+),%s*'wdth'%s*(%d+),%s*'slnt'%s*(%d+)"
    for weight_str, width_str, slant_str in html_content:gmatch(pattern) do
        local weight = tonumber(weight_str)
        local width = tonumber(width_str)
        local slant = tonumber(slant_str)

        if weight and width and slant then
            -- 从字体变体参数还原字节值
            local byte_value = math.floor((weight - 100) / 100) * 16 + math.floor(width / 6)
            table.insert(result, string.char(byte_value))
            logger.debug("Decoded font settings (weight=%d, width=%d, slant=%d) to byte: %d",
                weight, width, slant, byte_value)
        end
    end

    local decoded = table.concat(result)
    if #decoded > 0 then
        logger.info("Successfully decoded %d bytes from font variations", #decoded)
    else
        logger.warn("No data found in font variations")
    end

    return decoded
end

return font_encoder

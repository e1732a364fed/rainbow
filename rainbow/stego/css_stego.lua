local css_encoder = {}
local logger = require("rainbow.logger")

function css_encoder.encode(data)
    logger.debug("Encoding data using CSS animation steganography")

    -- 如果数据为空，返回基本结构
    if #data == 0 then
        return [[<!DOCTYPE html>
<html><head><title>Empty Page</title></head><body><div class="content"></div></body></html>]]
    end

    -- 将数据转换为二进制字符串
    local function to_binary(str)
        local binary = {}
        for i = 1, #str do
            local byte = str:byte(i)
            for j = 7, 0, -1 do -- 从高位到低位
                table.insert(binary, byte >= 2 ^ j and 1 or 0)
                if byte >= 2 ^ j then byte = byte - 2 ^ j end
            end
        end
        return binary
    end

    -- 生成随机的动画名称和元素ID
    local function random_name(prefix)
        return prefix .. tostring(math.random(10000, 99999))
    end

    -- 将二进制数据编码为CSS动画
    local binary_data = to_binary(data)
    local css_animations = {}
    local elements = {}

    for i = 1, #binary_data, 8 do
        local chunk = table.concat(binary_data, "", i, math.min(i + 7, #binary_data))
        local anim_name = random_name("a")
        local elem_id = random_name("e")

        -- 使用动画延迟编码数据
        local delays = {}
        for j = 1, #chunk do
            table.insert(delays, chunk:sub(j, j) == "1" and "0.1s" or "0.2s")
        end

        -- 创建动画和元素样式
        table.insert(css_animations, string.format([[
@keyframes %s {
    0%% { opacity: 1; }
    100%% { opacity: 1; }
}
#%s {
    animation: %s 1s;
    animation-delay: %s;
    display: inline-block;
    width: 1px;
    height: 1px;
    background: transparent;
}]], anim_name, elem_id, anim_name, table.concat(delays, ",")))

        table.insert(elements, string.format('<div id="%s"></div>', elem_id))
    end

    -- 生成完整的HTML
    local template = [[
<!DOCTYPE html>
<html>
<head>
    <title>Dynamic Content</title>
    <style>
        .content { font-family: Arial; line-height: 1.6; }
        %s
    </style>
</head>
<body>
    <div class="content">
        %s
        %s
    </div>
</body>
</html>]]

    logger.info("Generated CSS steganography with %d animations", #binary_data / 8)
    return string.format(template,
        table.concat(css_animations, "\n"),
        "Experience smooth animations and transitions.",
        table.concat(elements, "\n")
    )
end

function css_encoder.decode(html_content)
    logger.debug("Decoding CSS animation steganography")

    if not html_content or html_content == "" then
        return ""
    end

    -- 从CSS动画延迟时间中提取数据
    local binary = {}
    for delays in html_content:gmatch("animation%-delay:%s*([%d%.,s]+)") do
        for time in delays:gmatch("([%d%.]+)s") do
            table.insert(binary, time == "0.1" and "1" or "0")
        end
    end

    -- 将二进制转换回字符串
    local result = {}
    for i = 1, #binary, 8 do
        local byte = 0
        for j = 0, 7 do
            if i + j <= #binary then
                byte = byte + (binary[i + j] == "1" and 2 ^ (7 - j) or 0)
            end
        end
        table.insert(result, string.char(byte))
    end

    local decoded = table.concat(result)
    if #decoded > 0 then
        logger.info("Successfully decoded %d bytes", #decoded)
    else
        logger.warn("No data found in CSS animations")
    end

    return decoded
end

return css_encoder

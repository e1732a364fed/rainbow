local css_stego = {}

-- CSS 动画时间线隐写编码器
local css_encoder = {}

local logger = require("rainbow.logger")

function css_encoder.encode(data)
    logger.debug("Encoding data using CSS animation steganography")

    -- 创建一个基础的 HTML 结构，包含 CSS 动画
    local html_template = [[
<!DOCTYPE html>
<html>
<head>
    <title>%s</title>
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
</html>
]]

    -- 将数据转换为二进制字符串
    local function to_binary(str)
        local binary = {}
        for i = 1, #str do
            local byte = str:byte(i)
            for j = 8, 1, -1 do
                table.insert(binary, byte % 2)
                byte = math.floor(byte / 2)
            end
        end
        return binary
    end

    -- 生成随机的动画名称
    local function random_animation_name()
        return "a" .. tostring(math.random(10000, 99999))
    end

    -- 生成随机的元素 ID
    local function random_element_id()
        return "e" .. tostring(math.random(10000, 99999))
    end

    -- 将二进制数据编码为 CSS 动画时间
    local function encode_to_css_times(binary)
        local css_animations = {}
        local elements = {}

        for i = 1, #binary, 8 do
            local chunk = table.concat(binary, "", i, math.min(i + 7, #binary))
            local anim_name = random_animation_name()
            local elem_id = random_element_id()

            -- 使用动画延迟和持续时间来编码数据
            -- 1 编码为 0.1s，0 编码为 0.2s
            local delays = {}
            for j = 1, #chunk do
                table.insert(delays, chunk:sub(j, j) == "1" and "0.1s" or "0.2s")
            end

            -- 创建动画定义
            local animation = string.format([[
@keyframes %s {
    0%% { opacity: 1; }
    100%% { opacity: 1; }
}]], anim_name)

            -- 创建元素样式
            local element_style = string.format([[
#%s {
    animation: %s 1s;
    animation-delay: %s;
    display: inline-block;
    width: 1px;
    height: 1px;
    background: transparent;
}]], elem_id, anim_name, table.concat(delays, ","))

            table.insert(css_animations, animation)
            table.insert(css_animations, element_style)
            table.insert(elements, string.format('<div id="%s"></div>', elem_id))
        end

        return table.concat(css_animations, "\n"), table.concat(elements, "\n")
    end

    -- 生成随机的页面标题
    local titles = {
        "Interactive Design",
        "Modern Layout",
        "Dynamic Content",
        "Responsive Design"
    }
    local random_title = titles[math.random(#titles)]

    -- 生成随机的可见文本内容
    local visible_contents = {
        "Experience smooth animations and transitions.",
        "Modern web design with attention to detail.",
        "Optimized for the best user experience."
    }
    local visible_content = visible_contents[math.random(#visible_contents)]

    -- 将数据编码为 CSS 动画
    local binary_data = to_binary(data)
    local css_code, elements = encode_to_css_times(binary_data)

    logger.info("Generated CSS steganography with %d animations", #binary_data / 8)
    return string.format(html_template,
        random_title,
        css_code,
        visible_content,
        elements
    )
end

function css_encoder.decode(html_content)
    logger.debug("Decoding CSS animation steganography")

    -- 从 CSS 动画延迟时间中提取数据
    local binary = {}

    -- 提取所有动画延迟时间
    for delay in html_content:gmatch("animation%-delay:%s*([%d%.,s]+)") do
        -- 解析延迟时间序列
        for time in delay:gmatch("([%d%.]+)s") do
            -- 0.1s 表示 1，0.2s 表示 0
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

    if #result > 0 then
        logger.info("Successfully decoded %d bytes", #result)
    else
        logger.warn("No data found in CSS animations")
    end

    return table.concat(result)
end

-- 导出 CSS 编码器
css_stego.css_encoder = css_encoder

return css_stego

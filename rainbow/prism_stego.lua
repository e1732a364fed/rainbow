local prism_encoder = {}
local logger = require("rainbow.logger")

-- 彩虹编码实现
function prism_encoder.encode(data)
    logger.debug("Encoding data using Prism steganography")

    -- 如果数据为空，返回一个基本的 HTML 结构
    if #data == 0 then
        return [[
<!DOCTYPE html>
<html>
<head><title>Information Page</title></head>
<body><div class="content"></div></body>
</html>]]
    end

    local result = ""
    for i = 1, #data do
        local byte = data:byte(i)
        -- 直接将字节值加4作为深度
        local depth = byte + 4
        local tags = { "div", "span", "p" }
        local encoded = ""

        -- 使用随机的占位文本来增加真实性
        local placeholder_texts = {
            "Latest updates",
            "More information",
            "Click here",
            "Learn more"
        }

        -- 始终使用固定顺序的标签，但内容随机
        for d = 1, depth do
            encoded = string.format("<%s class='l%d'>%s</%s>",
                tags[1], -- 始终使用div作为外层
                d,
                d == depth and placeholder_texts[math.random(#placeholder_texts)] or encoded,
                tags[1])
        end
        result = result .. encoded .. "\n" -- 添加换行符以便更好地匹配
    end

    -- 添加一些随机的合法 HTML 内容来增加隐蔽性
    local template = [[
<!DOCTYPE html>
<html>
<head>
    <title>Information Page</title>
    <style>
        .content { font-family: Arial; }
        .l1, .l2, .l3, .l4 { margin: 5px; }
    </style>
</head>
<body>
    <div class="content">
        <h1>Welcome</h1>
%s
        <footer>Copyright © 2024</footer>
    </div>
</body>
</html>
]]

    logger.info("Generated Prism-encoded HTML with %d nested elements", #data)
    return string.format(template, result)
end

function prism_encoder.decode(html_content)
    logger.debug("Decoding Prism steganography")

    if not html_content or html_content == "" then
        return ""
    end

    local result = {}
    local content_section = html_content:match('<div class="content">(.-)</div>%s*</body>')
    if not content_section then
        return ""
    end

    -- 直接从class属性中提取数字
    local function extract_depth(block)
        local class_num = block:match('class=["\']l(%d+)["\']')
        return tonumber(class_num) or 0
    end

    -- 使用更灵活的正则表达式匹配 div 块
    for encoded_block in content_section:gmatch('(<div%s+class=["\']l%d+["\'].-</div>)') do
        if not encoded_block:match("Welcome") and not encoded_block:match("Copyright") then
            local depth = extract_depth(encoded_block)
            if depth >= 4 then
                local byte = depth - 4
                table.insert(result, string.char(byte))
            end
        end
    end

    local decoded = table.concat(result)
    if #decoded > 0 then
        logger.info("Successfully decoded %d bytes using Prism method", #decoded)
    else
        logger.warn("No data found in Prism-encoded content")
    end

    return decoded
end

return prism_encoder

local utils = {}
local logger = require("rainbow.logger")

-- Base64 编码表
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- 位运算辅助函数
local function band(a, b)
    local result = 0
    local bitval = 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then
            result = result + bitval
        end
        bitval = bitval * 2
        a = math.floor(a / 2)
        b = math.floor(b / 2)
    end
    return result
end

local function rshift(a, b)
    return math.floor(a / (2 ^ b))
end

local function lshift(a, b)
    return a * (2 ^ b)
end

-- Base64 编码
function utils.base64_encode(data)
    local bytes = {}
    local result = ""
    for i = 1, #data do
        bytes[i] = string.byte(data, i)
    end

    for i = 1, #bytes, 3 do
        local b1, b2, b3 = bytes[i], bytes[i + 1], bytes[i + 2]

        local c1 = rshift(b1, 2)
        local c2 = lshift(band(b1, 3), 4)
        local c3 = 0
        local c4 = 0

        if b2 then
            c2 = c2 + rshift(b2, 4)
            c3 = lshift(band(b2, 15), 2)
            if b3 then
                c3 = c3 + rshift(b3, 6)
                c4 = band(b3, 63)
            end
        end

        result = result .. b64chars:sub(c1 + 1, c1 + 1)
        result = result .. b64chars:sub(c2 + 1, c2 + 1)
        result = result .. (b2 and b64chars:sub(c3 + 1, c3 + 1) or '=')
        result = result .. (b3 and b64chars:sub(c4 + 1, c4 + 1) or '=')
    end

    return result
end

-- Base64 解码
function utils.base64_decode(data)
    local b64dec = {}
    for i = 1, #b64chars do
        b64dec[b64chars:sub(i, i)] = i - 1
    end

    local result = ""
    data = string.gsub(data, '[^' .. b64chars .. '=]', '')

    for i = 1, #data - 3, 4 do
        local c1 = b64dec[data:sub(i, i)]
        local c2 = b64dec[data:sub(i + 1, i + 1)]
        local c3 = b64dec[data:sub(i + 2, i + 2)]
        local c4 = b64dec[data:sub(i + 3, i + 3)]

        if c3 == nil then c3 = 0 end
        if c4 == nil then c4 = 0 end

        result = result .. string.char(
            lshift(c1, 2) + rshift(c2, 4),
            lshift(band(c2, 15), 4) + rshift(c3, 2),
            lshift(band(c3, 3), 6) + c4
        )
    end

    -- 处理填充
    if data:sub(-2) == '==' then
        result = result:sub(1, -3)
    elseif data:sub(-1) == '=' then
        result = result:sub(1, -2)
    end

    return result
end

-- 生成随机的 HTTP 头部
function utils.generate_realistic_headers()
    logger.debug("Generating realistic HTTP headers")
    local user_agents = {
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }

    local referers = {
        "https://www.google.com",
        "https://www.bing.com",
        "https://www.yahoo.com"
    }

    -- 生成真实的时间戳
    local function get_http_date()
        return os.date("!%a, %d %b %Y %H:%M:%S GMT")
    end

    local headers = {
        ["User-Agent"] = user_agents[math.random(#user_agents)],
        ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        ["Accept-Language"] = "en-US,en;q=0.5",
        ["Accept-Encoding"] = "gzip, deflate, br",
        ["Connection"] = "keep-alive",
        ["Referer"] = referers[math.random(#referers)],
        ["Date"] = get_http_date()
    }

    logger.debug("Generated headers with %d fields", #headers)
    return headers
end

-- 随机化延迟函数
function utils.random_delay()
    local min_delay = 50  -- 最小延迟 50ms
    local max_delay = 200 -- 最大延迟 200ms
    local delay = math.random(min_delay, max_delay)
    logger.debug("Generated random delay: %dms", delay)
    return delay
end

-- 生成随机的数据包大小
function utils.random_packet_size()
    local min_size = 500
    local max_size = 1500
    local size = math.random(min_size, max_size)
    logger.debug("Generated random packet size: %d bytes", size)
    return size
end

function utils.hex_dump(str)
    if not str or str == "" then
        return "<empty string>"
    end

    local result = {}
    for i = 1, #str do
        table.insert(result, string.format("%02X", str:byte(i)))
    end
    return table.concat(result, " ")
end

-- 可选：添加一个更详细的十六进制打印函数
function utils.hex_dump_detailed(str)
    if not str or str == "" then
        return "<empty string>"
    end

    local result = {
        "Length: " .. #str .. " bytes",
        "Hex: " .. utils.hex_dump(str),
        "ASCII: "
    }

    -- 添加 ASCII 表示（可打印字符显示原字符，不可打印字符显示点）
    local ascii = {}
    for i = 1, #str do
        local byte = str:byte(i)
        if byte >= 32 and byte <= 126 then
            table.insert(ascii, string.char(byte))
        else
            table.insert(ascii, ".")
        end
    end
    table.insert(result, table.concat(ascii))

    return table.concat(result, "\n")
end

return utils

local stego = require("rainbow.stego")
local sequence = require("rainbow.sequence")
local handshake = require("rainbow.handshake")
local utils = require("rainbow.utils")
local logger = require("rainbow.logger")
local error_handler = require("rainbow.error")

local rainbow = {}

-- 在 rainbow/main.lua 中添加新的错误类型
local ERROR_DETAILS = {
    MIME_TYPE_MISSING = "Missing Content-Type header",
    CONTENT_MISSING = "Missing content body",
    BASE64_DECODE_FAILED = "Failed to decode Base64 data",
    INVALID_PACKET_FORMAT = "Invalid packet format",
    UNSUPPORTED_MIME_TYPE = "Unsupported MIME type"
}

-- 添加 Cookie 相关的常量和辅助函数
local COOKIE_NAMES = {
    "sessionId",
    "visitor",
    "track",
    "_ga",
    "_gid",
    "JSESSIONID",
    "cf_id"
}

-- 将包信息编码为 Cookie 值
local function encode_packet_info(packet_info)
    if not packet_info then return nil end


    -- 构造看起来像正常 Cookie 的值
    -- 格式: v1.时间戳.total_packets.expected_length.随机值

    local parts = {
        "v1",
        tostring(os.time()),
        packet_info.total_packets and tostring(packet_info.total_packets) or "0",
        tostring(packet_info.expected_length),
        utils.random_string(8) -- 添加随机值增加真实性
    }


    -- Base64 编码使其看起来像正常的 Cookie
    return utils.base64_encode(table.concat(parts, "."))
end

-- 从 Cookie 值解码包信息
local function decode_packet_info(cookie_value)
    if not cookie_value then return nil end

    local decoded = utils.base64_decode(cookie_value)
    if not decoded then return nil end

    -- 修改正则表达式以正确匹配所有字段
    local parts = {}
    for part in decoded:gmatch("[^%.]+") do
        table.insert(parts, part)
    end

    -- 确保有足够的部分
    if #parts >= 5 and parts[1] == "v1" then
        return {
            total_packets = tonumber(parts[3]),
            expected_length = tonumber(parts[4])
        }
    end

    return nil
end

-- 在 rainbow.decode 函数中修改 Cookie 解析部分
local function parse_cookies(cookie_header)
    if not cookie_header then return nil end

    -- 遍历所有 cookie
    for cookie in cookie_header:gmatch("[^;]+") do
        local name, value = cookie:match("^%s*([^=]+)=(.+)")
        if name and value then
            -- 尝试解码每个 cookie 值
            local packet_info = decode_packet_info(value:match("^%s*(.-)%s*$"))
            if packet_info then
                return packet_info
            end
        end
    end
    return nil
end

-- 构建 HTTP 请求
local function build_http_request(method, headers, content, mime_type, path, packet_info)
    if not method then
        method = "POST"
    end


    -- 如果没有提供路径，生成一个随机的真实路径
    if not path then
        local paths = {
            "/",
            "/index.html",
            "/assets/main.css",
            "/js/app.js",
            "/api/v1/data",
            "/images/logo.png",
            "/blog/latest",
            "/docs/guide"
        }
        -- 对于POST请求，使用更合适的API路径
        if method == "POST" then
            paths = {
                "/api/v1/data",
                "/api/v1/upload",
                "/api/v2/submit",
                "/upload",
                "/submit",
                "/process"
            }
        end
        path = paths[math.random(#paths)]
    end

    -- 构建请求行
    local request_lines = {
        string.format("%s %s HTTP/1.1\r\n", method, path)
    }

    -- 添加基本头部
    headers = headers or {}
    headers["Host"] = "example.com"
    headers["User-Agent"] = "Mozilla/5.0"
    headers["Connection"] = "keep-alive"

    if method == "GET" then
        -- GET请求：将部分数据编码到headers中
        -- 将内容编码到自定义header中
        local encoded_data = utils.base64_encode(content)
        headers["X-Data"] = encoded_data
        headers["Accept"] = "*/*"
        content = "" -- GET请求不应该有body
    else
        -- POST请求：正常设置Content-Type和Content-Length
        headers["Content-Type"] = mime_type
        headers["Content-Length"] = tostring(#content)
        headers["Accept"] = "*/*"

        -- 添加一些典型的POST请求头
        -- headers["Origin"] = "https://example.com"
        -- headers["Referer"] = "https://example.com/"
    end


    -- 根据路径添加相关的头部
    if path:match("%.css$") then
        headers["Accept"] = "text/css,*/*;q=0.1"
    elseif path:match("%.js$") then
        headers["Accept"] = "application/javascript,*/*;q=0.1"
    elseif path:match("%.png$") then
        headers["Accept"] = "image/png,image/*;q=0.8,*/*;q=0.5"
    elseif path:match("^/api/") then
        headers["Accept"] = "application/json"
        -- headers["X-Requested-With"] = "XMLHttpRequest"
    end
    if packet_info then
        local cookie_name = COOKIE_NAMES[math.random(#COOKIE_NAMES)]
        local cookie_value = encode_packet_info(packet_info)

        -- 添加其他真实的 Cookie 来混淆
        local cookies = {
            string.format("%s=%s", cookie_name, cookie_value),
            "_ga=GA1." .. utils.random_string(8),
            "theme=light",
            "lang=en-US"
        }

        headers["Cookie"] = table.concat(cookies, "; ")
    end

    -- 添加所有头部（按字母顺序）
    local sorted_headers = {}
    for name, _ in pairs(headers) do
        table.insert(sorted_headers, name)
    end
    table.sort(sorted_headers)

    for _, name in ipairs(sorted_headers) do
        table.insert(request_lines, string.format("%s: %s\r\n", name, headers[name]))
    end


    -- 添加空行和内容
    table.insert(request_lines, "\r\n")
    table.insert(request_lines, content)

    -- 记录调试信息
    logger.debug("Generated HTTP request:")
    logger.debug("  Method: %s", method)
    logger.debug("  Path: %s", path)
    logger.debug("  MIME type: %s", mime_type)
    logger.debug("  Content length: %d", #content)



    return table.concat(request_lines)
end

-- 构建 HTTP 响应
local function build_http_response(headers, content, mime_type, status_code, packet_info)
    local response_lines = {
        string.format("HTTP/1.1 %d OK\r\n", status_code or 200)
    }

    -- 添加基本头部
    headers = headers or {}
    headers["Server"] = "nginx/1.18.0"
    headers["Date"] = os.date("!%a, %d %b %Y %H:%M:%S GMT")
    headers["Connection"] = "keep-alive"
    headers["Content-Type"] = mime_type
    headers["Content-Length"] = tostring(#content)

    -- 添加 Cookie 信息
    if packet_info then
        local cookie_name = COOKIE_NAMES[math.random(#COOKIE_NAMES)]

        local cookie_value = encode_packet_info(packet_info)

        -- 添加其他真实的 Cookie 来混淆
        local cookies = {
            string.format("%s=%s", cookie_name, cookie_value),
            "_ga=GA1." .. utils.random_string(8),
            "theme=light",
            "lang=en-US"
        }

        headers["Cookie"] = table.concat(cookies, "; ")
    end

    -- 添加所有头部
    for name, value in pairs(headers) do
        table.insert(response_lines, string.format("%s: %s\r\n", name, value))
    end

    -- 添加空行和内容
    table.insert(response_lines, "\r\n")
    table.insert(response_lines, content)


    return table.concat(response_lines)
end

-- 编码要写入的数据为 HTTP 请求/响应序列, 返回 http_packets, expected_lengths
function rainbow.encode(data, is_client, force_mime_type)
    logger.debug("Starting encoding process: client=%s", tostring(is_client))

    if type(data) ~= "string" then
        return error_handler.create_error(
            error_handler.ERROR_TYPE.INVALID_DATA,
            "Input must be string"
        )
    end

    return error_handler.try(function()
        local write_seq, expected_lengths = sequence.generate_sequence(data, is_client)

        if not write_seq then
            return error_handler.create_error(
                error_handler.ERROR_TYPE.ENCODE_FAILED,
                "Failed to generate sequence"
            )
        end

        local http_packets = {}
        for i, chunk in ipairs(write_seq) do
            local mime_type = force_mime_type or stego.get_random_mime_type()
            local headers = utils.generate_realistic_headers()

            local encoded_content = stego.encode_mime(chunk, mime_type)
            if not encoded_content then
                return error_handler.create_error(
                    error_handler.ERROR_TYPE.ENCODE_FAILED,
                    "Failed to encode data"
                )
            end

            -- 构建包信息
            local packet_info = {
                expected_length = expected_lengths[i],
                is_first_packet = (i == 1),
                total_packets = #write_seq
            }

            -- 构建 HTTP 包
            local http_packet
            if is_client then
                http_packet = build_http_request(nil, headers, encoded_content, mime_type, nil, packet_info)
            else
                http_packet = build_http_response(headers, encoded_content, mime_type, 200, packet_info)
            end


            table.insert(http_packets, http_packet)
        end

        if #http_packets == 0 then
            return error_handler.create_error(
                error_handler.ERROR_TYPE.ENCODE_FAILED,
                "No packets generated"
            )
        end

        return http_packets, expected_lengths
    end)
end

local function decode_single_packet(packet, packet_index)
    local header, content = packet:match("(.-)\r\n\r\n(.*)$")
    if not header then
        return nil, ERROR_DETAILS.INVALID_PACKET_FORMAT
    end

    -- 获取请求方法
    local first_line = header:match("^[^\r\n]+")
    local is_get = first_line and first_line:match("^GET")

    if is_get then
        -- 从header中解码数据
        local encoded_data = header:match("[Xx]%-[Dd]ata:%s*([^%s\r\n]+)")
        if encoded_data then
            return utils.base64_decode(encoded_data)
        end
    end

    local mime_type = header:match("[Cc]ontent%-[Tt]ype:%s*([^%s;,\r\n]+)")
    if not mime_type then
        return nil, ERROR_DETAILS.MIME_TYPE_MISSING
    end

    if not content then
        return nil, ERROR_DETAILS.CONTENT_MISSING
    end

    logger.debug("Processing packet %d:", packet_index)
    logger.debug("  MIME type: %s", mime_type)
    logger.debug("  Content length: %d", #content)

    -- 添加调试日志
    local decoded = stego.decode_mime(content, mime_type)
    if not decoded then
        logger.error("Failed to decode content with MIME type: %s", mime_type)
        return nil, "Failed to decode content"
    end

    logger.debug("Successfully decoded content: length=%d", #decoded)
    return decoded
end

-- 修改 validate_http_packet 函数的实现
local function validate_http_packet(pkt)
    -- 添加调试日志
    logger.debug("Validating HTTP packet format:")
    logger.debug("First line: %s", pkt:match("^[^\r\n]+"))

    -- 修改正则表达式以更宽松地匹配 HTTP 格式
    local first_line = pkt:match("^[^\r\n]+")
    if not first_line then
        return false
    end

    -- 检查是否是响应
    if first_line:match("^HTTP/[%d%.]+%s+%d+") then
        logger.debug("Valid HTTP response format")
        return true
    end

    -- 检查是否是请求
    if first_line:match("^[A-Z]+%s+[^%s]+%s+HTTP/[%d%.]+") then
        logger.debug("Valid HTTP request format")
        return true
    end

    logger.debug("Invalid HTTP format")
    return false
end

-- 解码读取到的单个 packet 为 decoded, expected_return_length, is_read_end
function rainbow.decode(packet, packet_index, is_client)
    if type(packet) ~= "string" then
        return error_handler.create_error(
            error_handler.ERROR_TYPE.INVALID_DATA,
            "Packet must be a string"
        )
    end

    -- 验证 HTTP 包格式
    if not validate_http_packet(packet) then
        logger.error("Invalid HTTP packet format")
        logger.debug("Packet start: %s", packet:sub(1, 100))
        return error_handler.create_error(
            error_handler.ERROR_TYPE.INVALID_DATA,
            "Invalid packet format"
        )
    end

    -- 获取包信息
    local header = packet:match("(.-)\r\n\r\n")
    if not header then
        logger.error("Failed to extract header")
        return error_handler.create_error(
            error_handler.ERROR_TYPE.INVALID_DATA,
            "Invalid packet format: no header found"
        )
    end

    -- 从 Cookie 中获取包信息
    local cookie_header = header:match("[Cc]ookie:%s*([^\r\n]+)")
    local total_packets, expected_return_length

    if cookie_header then
        local packet_info = parse_cookies(cookie_header)
        if packet_info then
            total_packets = packet_info.total_packets
            expected_return_length = packet_info.expected_length
        end
    end


    -- 解码数据
    local decoded, err = decode_single_packet(packet, packet_index)
    if not decoded then
        logger.error("Failed to decode packet: %s", err or "unknown error")
        return error_handler.create_error(
            error_handler.ERROR_TYPE.DECODE_FAILED,
            err or "Failed to decode packet"
        )
    end

    -- 判断是否是最后一个包
    local is_read_end = total_packets and (packet_index == total_packets)

    return decoded, expected_return_length, is_read_end
end

-- 验证数据包长度
function rainbow.verify_length(packet, expected_length)
    logger.debug("Verifying packet length: expected=%d", expected_length)

    local content_length = packet:match("Content%-Length:%s*(%d+)")
    if content_length then
        content_length = tonumber(content_length)
        if content_length ~= expected_length then
            local err = error_handler.create_error(
                error_handler.ERROR_TYPE.LENGTH_MISMATCH,
                expected_length,
                content_length
            )
            logger.warn(err.message)
            return false
        end
        return true
    end

    logger.warn("Content-Length header not found")
    return false
end

return rainbow

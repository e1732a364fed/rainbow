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
        if #content <= 1024 then
            -- 将内容编码到自定义header中
            local encoded_data = utils.base64_encode(content)
            headers["X-Data"] = encoded_data
            headers["Accept"] = "*/*"
            content = "" -- GET请求不应该有body
        end
    else
        -- POST请求：正常设置Content-Type和Content-Length
        headers["Content-Type"] = mime_type
        headers["Content-Length"] = tostring(#content)
        headers["Accept"] = "*/*"

        -- 添加一些典型的POST请求头
        headers["Origin"] = "https://example.com"
        headers["Referer"] = "https://example.com/"
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

    -- 添加包信息相关的header
    if packet_info then
        if packet_info.is_first_packet then
            headers["X-Total-Packets"] = tostring(packet_info.total_packets)
        end
        headers["X-Expected-Length"] = tostring(packet_info.expected_length)
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

    -- 添加所有头部
    for name, value in pairs(headers) do
        table.insert(response_lines, string.format("%s: %s\r\n", name, value))
    end

    -- 添加空行和内容
    table.insert(response_lines, "\r\n")
    table.insert(response_lines, content)

    -- 添加包信息相关的header
    if packet_info then
        if packet_info.is_first_packet then
            headers["X-Total-Packets"] = tostring(packet_info.total_packets)
        end
        headers["X-Expected-Length"] = tostring(packet_info.expected_length)
    end

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

-- 解码读取到的单个 packet 为 decoded, expected_return_length, is_read_end
function rainbow.decode(packet, packet_index, is_client)
    if type(packet) ~= "string" then
        return error_handler.create_error(
            error_handler.ERROR_TYPE.INVALID_DATA,
            "Packet must be a string"
        )
    end

    -- 验证HTTP包格式
    local function validate_http_packet(pkt)
        -- 添加调试日志
        logger.debug("Validating HTTP packet format:")
        logger.debug("First line: %s", pkt:match("^[^\r\n]+"))

        if is_client then
            -- 客户端接收响应
            local valid = pkt:match("^HTTP/[0-9.]+ %d+ .+\r\n")
            logger.debug("Validating as client (response): %s", tostring(valid ~= nil))
            return valid
        else
            -- 服务端接收请求
            local valid = pkt:match("^[A-Z]+ .+ HTTP/[0-9.]+\r\n")
            logger.debug("Validating as server (request): %s", tostring(valid ~= nil))
            return valid
        end
    end

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

    print(header)

    local total_packets = tonumber(header:match("[Xx]%-[Tt]otal%-[Pp]ackets:%s*(%d+)"))
    local expected_return_length = tonumber(header:match("[Xx]%-[Ee]xpected%-[Ll]ength:%s*(%d+)"))

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

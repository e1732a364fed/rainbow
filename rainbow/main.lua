local stego = require("rainbow.stego")
local sequence = require("rainbow.sequence")
local handshake = require("rainbow.handshake")
local utils = require("rainbow.utils")
local logger = require("rainbow.logger")
local error_handler = require("rainbow.error")

local rainbow = {}

-- 数据包类型
local PACKET_TYPE = {
    HANDSHAKE = 1,
    DATA = 2
}

-- 在 rainbow/main.lua 中添加新的错误类型
local ERROR_DETAILS = {
    MIME_TYPE_MISSING = "Missing Content-Type header",
    CONTENT_MISSING = "Missing content body",
    BASE64_DECODE_FAILED = "Failed to decode Base64 data",
    INVALID_PACKET_FORMAT = "Invalid packet format",
    UNSUPPORTED_MIME_TYPE = "Unsupported MIME type"
}

-- 构建 HTTP 请求
local function build_http_request(headers, content, mime_type, path)
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
        path = paths[math.random(#paths)]
    end

    -- 构建请求行
    local request_lines = {
        string.format("GET %s HTTP/1.1\r\n", path)
    }

    -- 添加基本头部
    headers = headers or {}
    headers["Host"] = "example.com"
    headers["User-Agent"] = "Mozilla/5.0"
    headers["Accept"] = "*/*"
    headers["Connection"] = "keep-alive"
    headers["Content-Type"] = mime_type
    headers["Content-Length"] = tostring(#content)

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
    logger.debug("  Path: %s", path)
    logger.debug("  MIME type: %s", mime_type)
    logger.debug("  Content length: %d", #content)

    return table.concat(request_lines)
end

-- 构建 HTTP 响应
local function build_http_response(headers, content, mime_type, status_code)
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

    return table.concat(response_lines)
end

-- 编码数据为 HTTP 请求/响应序列, packet_type 值是 PACKET_TYPE 之一
function rainbow.encode(data, is_client, packet_type, force_mime_type)
    logger.debug("Starting encoding process: client=%s, type=%d", tostring(is_client), packet_type)

    -- 验证输入数据
    if type(data) ~= "string" then
        return error_handler.create_error(
            error_handler.ERROR_TYPE.INVALID_DATA,
            "Input must be string"
        )
    end

    return error_handler.try(function()
        if packet_type == PACKET_TYPE.HANDSHAKE then
            -- 处理握手请求
            local requests, response_lengths = handshake.encode_request(data)
            if not requests then
                return error_handler.create_error(
                    error_handler.ERROR_TYPE.ENCODE_FAILED,
                    "Failed to encode handshake request"
                )
            end

            local http_packets = {}
            for _, request in ipairs(requests) do
                -- 强制使用 JSON 编码器
                request.mime_type = "application/json"
                local http_request = build_http_request(
                    request.headers or {},
                    request.content,
                    request.mime_type,
                    request.path
                )
                table.insert(http_packets, http_request)
            end

            logger.info("Successfully encoded handshake request with %d packets", #http_packets)
            return http_packets, response_lengths
        else
            -- 处理数据传输
            local write_seq, read_seq = sequence.generate_sequence(data, is_client)
            if not write_seq then
                return error_handler.create_error(
                    error_handler.ERROR_TYPE.ENCODE_FAILED,
                    "Failed to generate sequence"
                )
            end

            local http_packets = {}
            local expected_lengths = read_seq

            for i, chunk in ipairs(write_seq) do
                -- 使用强制的 MIME 类型或随机选择一个
                local mime_type = force_mime_type or stego.get_random_mime_type()
                local headers = utils.generate_realistic_headers()

                -- 使用 stego 模块进行编码
                local encoded_content = stego.encode_mime(chunk, mime_type)
                if not encoded_content then
                    return error_handler.create_error(
                        error_handler.ERROR_TYPE.ENCODE_FAILED,
                        "Failed to encode data"
                    )
                end

                -- 构建 HTTP 包
                local http_packet
                if is_client then
                    http_packet = build_http_request(headers, encoded_content, mime_type, nil)
                else
                    http_packet = build_http_response(headers, encoded_content, mime_type, 200)
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
        end
    end)
end

-- 添加一个新的辅助函数来处理包的解码
local function decode_single_packet(packet, packet_type, packet_index)
    -- 提取 MIME 类型和内容
    local mime_type = packet:match("[Cc]ontent%-[Tt]ype:%s*([^%s;,\r\n]+)")
    local content = packet:match("\r\n\r\n(.+)$")

    if not mime_type then
        return nil, ERROR_DETAILS.MIME_TYPE_MISSING
    end

    if not content then
        return nil, ERROR_DETAILS.CONTENT_MISSING
    end

    -- 记录调试信息
    logger.debug("Processing packet %d:", packet_index)
    logger.debug("  MIME type: %s", mime_type)
    logger.debug("  Content length: %d", #content)

    -- 解码内容
    local decoded = stego.decode_mime(content, mime_type)
    if not decoded then
        return nil, ERROR_DETAILS.UNSUPPORTED_MIME_TYPE
    end

    if packet_type == PACKET_TYPE.HANDSHAKE then
        -- 对于握手包，需要解码 Base64 数据
        local final_decoded = utils.base64_decode(decoded)
        if not final_decoded then
            return nil, ERROR_DETAILS.BASE64_DECODE_FAILED
        end
        return final_decoded
    end

    return decoded
end

-- 修改 decode 函数中的处理逻辑
function rainbow.decode(packets, is_client, packet_type)
    -- 输入验证
    if type(packets) ~= "table" and type(packets) ~= "string" then
        return error_handler.create_error(
            error_handler.ERROR_TYPE.INVALID_DATA,
            "Packets must be either a table or string"
        )
    end

    -- 如果输入是字符串，转换为表
    if type(packets) == "string" then
        -- 如果输入是单个字符串且不包含 HTTP 头部，返回 INVALID_DATA
        if not packets:match("HTTP/[0-9.]+") and not packets:match(" HTTP/[0-9.]+") then
            return error_handler.create_error(
                error_handler.ERROR_TYPE.INVALID_DATA,
                "Invalid packet format"
            )
        end
        packets = { packets }
    end

    -- 添加对 is_client 的处理逻辑
    local function validate_http_packet(packet)
        if is_client then
            -- 客户端模式：验证 HTTP 响应格式
            return packet:match("^HTTP/[0-9.]+ %d+ .+\r\n")
        else
            -- 服务器模式：验证 HTTP 请求格式
            return packet:match("^[A-Z]+ .+ HTTP/[0-9.]+\r\n")
        end
    end

    -- 验证每个数据包
    local decode_errors = {}
    local all_decoded = {}
    for i, packet in ipairs(packets) do
        if type(packet) ~= "string" then
            table.insert(decode_errors, {
                packet = i,
                reason = ERROR_DETAILS.INVALID_PACKET_FORMAT
            })
            goto next_packet
        end

        if not validate_http_packet(packet) then
            table.insert(decode_errors, {
                packet = i,
                reason = ERROR_DETAILS.INVALID_PACKET_FORMAT
            })
            goto next_packet
        end

        local decoded, err = decode_single_packet(packet, packet_type, i)
        if decoded then
            table.insert(all_decoded, decoded)
        else
            table.insert(decode_errors, {
                packet = i,
                reason = err
            })
        end

        ::next_packet::
    end

    -- 如果没有成功解码任何包
    if #all_decoded == 0 then
        local error_msg = "Failed to decode packets:\n"
        for _, err in ipairs(decode_errors) do
            error_msg = error_msg .. string.format("  Packet %d: %s\n",
                err.packet, err.reason)
        end
        return error_handler.create_error(
            error_handler.ERROR_TYPE.DECODE_FAILED,
            error_msg
        )
    end

    -- 返回所有解码后的数据
    return table.concat(all_decoded)
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

-- 导出包类型常量
rainbow.PACKET_TYPE = PACKET_TYPE

return rainbow

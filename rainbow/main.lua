local mime = require("rainbow.mime_encoder")
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

    local request_lines = {
        string.format("GET %s HTTP/1.1\r\n", path)
    }

    -- 添加基本头部
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
        headers["X-Requested-With"] = "XMLHttpRequest"
    end

    -- 添加所有头部
    for name, value in pairs(headers) do
        table.insert(request_lines, string.format("%s: %s\r\n", name, value))
    end

    -- 添加空行和内容
    table.insert(request_lines, "\r\n")
    table.insert(request_lines, content)

    return table.concat(request_lines)
end

-- 构建 HTTP 响应
local function build_http_response(headers, content, mime_type, status_code)
    local response_lines = {
        string.format("HTTP/1.1 %d OK\r\n", status_code or 200)
    }

    -- 添加基本头部
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

-- 编码数据为 HTTP 请求/响应序列
function rainbow.encode(data, is_client, packet_type)
    logger.debug("Starting encoding process: client=%s, type=%d", tostring(is_client), packet_type)

    -- 验证输入数据
    if type(data) ~= "string" then
        local err = error_handler.create_error(error_handler.ERROR_TYPE.INVALID_DATA, "input must be string")
        logger.warn(err.message)
        return err
    end

    return error_handler.try(function()
        if packet_type == PACKET_TYPE.HANDSHAKE then
            -- 处理握手请求
            local requests, response_lengths = handshake.encode_request(data)
            local http_packets = {}

            for _, request in ipairs(requests) do
                local http_request = build_http_request(
                    request.headers,
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
            local http_packets = {}
            local expected_lengths = {}

            for i, chunk in ipairs(write_seq) do
                -- 优先考虑使用 CSS 隐写，增加其使用概率
                local mime_types = {
                    "text/html+css",      -- CSS 隐写
                    "text/html",          -- HTML 隐写
                    "application/json",   -- JSON 隐写
                    "application/xml",    -- XML 隐写
                    "image/svg+xml",      -- SVG 隐写
                    "application/rss+xml" -- RSS 隐写
                }
                local mime_type = mime_types[math.random(#mime_types)]

                local headers = utils.generate_realistic_headers()
                local encoded_content = mime.encode(chunk, mime_type)

                -- 构建 HTTP 包
                local http_packet
                if is_client then
                    http_packet = build_http_request(
                        headers,
                        encoded_content,
                        mime_type,
                        nil
                    )
                else
                    http_packet = build_http_response(headers, encoded_content, mime_type, 200)
                end

                table.insert(http_packets, http_packet)
                table.insert(expected_lengths, read_seq[i])
            end

            return http_packets, expected_lengths
        end
    end)
end

-- 从 HTTP 请求/响应中解码数据
function rainbow.decode(packets, is_client, packet_type)
    logger.debug("Starting decoding process: client=%s, type=%d", tostring(is_client), packet_type)

    -- 验证输入数据
    if type(packets) ~= "table" then
        local err = error_handler.create_error(error_handler.ERROR_TYPE.INVALID_DATA, "packets must be table")
        logger.warn(err.message)
        return err
    end

    return error_handler.try(function()
        if packet_type == PACKET_TYPE.HANDSHAKE then
            -- 处理握手请求
            if is_client then
                return handshake.decode_response(packets)
            else
                return handshake.decode_request(packets)
            end
        else
            -- 处理数据传输
            local data_parts = {}

            for _, packet in ipairs(packets) do
                -- 提取 MIME 类型
                local mime_type = packet:match("Content%-Type:%s*([^\r\n]+)")
                -- 提取内容
                local content = packet:match("\r\n\r\n(.+)$")

                if mime_type and content then
                    local decoded = mime.decode(content, mime_type)
                    if decoded then
                        table.insert(data_parts, decoded)
                    end
                end
            end

            return table.concat(data_parts)
        end
    end)
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

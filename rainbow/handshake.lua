local stego = require("rainbow.stego")
local sequence = require("rainbow.sequence")
local utils = require("rainbow.utils")
local logger = require("rainbow.logger")
local error_handler = require("rainbow.error")

local handshake = {}

-- 目标地址结构编码器
local function encode_target_address(address)
    -- 地址格式: protocol://host:port
    -- 例如: tcp://example.com:443
    return utils.base64_encode(address)
end

-- 目标地址结构解码器
local function decode_target_address(encoded)
    local result = {}

    -- 先将 Base64 解码为原始字符串
    local decoded = utils.base64_decode(encoded)
    if not decoded then
        return nil
    end

    return decoded
end

-- 编码握手请求
function handshake.encode_request(target)
    logger.debug("Encoding handshake request for target: %s", target)

    -- 编码目标地址
    local encoded_target = encode_target_address(target)
    if not encoded_target then
        logger.error("Failed to encode target address")
        return nil
    end

    -- 生成请求序列
    local write_seq, read_seq = sequence.generate_sequence(encoded_target, true)
    if not write_seq then
        logger.error("Failed to generate sequence")
        return nil
    end

    -- 构建请求序列
    local requests = {}
    local response_lengths = {}

    for i, chunk in ipairs(write_seq) do
        -- 使用 JSON 编码器
        local request = {
            mime_type = "application/json",
            headers = utils.generate_realistic_headers(),
            path = i == 1 and "/api/v1/session" or "/api/v1/data"
        }

        -- 为第一个请求添加特殊头部
        if i == 1 then
            request.headers["Cache-Control"] = "no-cache"
            request.headers["X-Request-ID"] = utils.generate_uuid()
        end

        -- 编码数据
        request.content = stego.encode_mime(chunk, request.mime_type)
        if not request.content then
            logger.error("Failed to encode chunk %d", i)
            return nil
        end

        -- 记录调试信息
        logger.debug("Generated request %d:", i)
        logger.debug("  MIME type: %s", request.mime_type)
        logger.debug("  Content length: %d", #request.content)

        table.insert(requests, request)
        table.insert(response_lengths, read_seq[i])
    end

    if #requests == 0 then
        logger.error("No requests generated")
        return nil
    end

    logger.info("Generated handshake request with %d packets", #requests)
    return requests, response_lengths
end

-- 解码握手请求
function handshake.decode_request(request_sequence)
    logger.debug("Decoding handshake request with %d packets", #request_sequence)

    local data_parts = {}

    -- 从请求序列中提取数据
    for _, request in ipairs(request_sequence) do
        local decoded = stego.decode_mime(request.content, request.mime_type, request.encoder)
        if decoded then
            table.insert(data_parts, decoded)
        end
    end

    -- 合并数据并解码目标地址
    local encoded_address = table.concat(data_parts)
    local target = decode_target_address(encoded_address)
    logger.info("Decoded target address: %s", target)
    return target
end

-- 生成握手响应
function handshake.encode_response(success, error_message)
    logger.debug("Encoding handshake response: success=%s, error=%s",
        tostring(success), error_message or "none")

    local response_data = {
        status = success and "ok" or "error",
        message = error_message or ""
    }

    -- 将响应数据编码为 JSON
    local json_str = string.format('{"s":"%s","m":"%s"}',
        response_data.status,
        response_data.message
    )

    -- 生成响应序列
    local write_seq, read_seq = sequence.generate_sequence(json_str, true)

    -- 构建响应序列
    local responses = {}
    local request_lengths = {}

    for i = 1, #write_seq do
        local mime_type = stego.get_random_mime_type()
        local content, encoder = stego.encode_mime(write_seq[i], mime_type)
        local response = {
            headers = utils.generate_realistic_headers(),
            mime_type = mime_type,
            content = content,
            encoder = encoder, -- 保存使用的编码器以便解码时使用
            expected_request_length = read_seq[i]
        }
        table.insert(responses, response)
        table.insert(request_lengths, read_seq[i])
    end

    logger.info("Generated handshake response with %d packets", #responses)
    return responses, request_lengths
end

-- 解码握手响应
function handshake.decode_response(response_sequence)
    logger.debug("Decoding handshake response with %d packets", #response_sequence)

    local data_parts = {}

    -- 从响应序列中提取数据
    for _, response in ipairs(response_sequence) do
        local decoded = stego.decode_mime(response.content, response.mime_type, response.encoder)
        if decoded then
            table.insert(data_parts, decoded)
        end
    end

    -- 解析 JSON 响应
    local json_str = table.concat(data_parts)
    local status = json_str:match('"s":"([^"]+)"')
    local message = json_str:match('"m":"([^"]*)"')

    -- 如果解析失败，返回错误状态
    if not status then
        return {
            success = false,
            error_message = "Invalid response format"
        }
    end

    local result = {
        success = (status == "ok"),
        error_message = message or ""
    }

    if not result.success then
        logger.warn("Handshake failed: %s", result.error_message)
    else
        logger.info("Handshake completed successfully")
    end

    return result
end

return handshake

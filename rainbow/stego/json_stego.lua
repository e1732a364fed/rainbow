local json_encoder = {}
local logger = require("rainbow.logger")
local utils = require("rainbow.utils")

-- 添加模块名称
json_encoder.name = "json"

function json_encoder.encode(data)
    logger.debug("Encoding data using JSON metadata steganography")

    if #data == 0 then
        return "{}"
    end

    -- 将数据编码为 Base64 并嵌入 JSON
    local encoded = utils.base64_encode(data)

    -- 构建 JSON 文档
    local template = [[{
    "type": "metadata",
    "version": "1.0",
    "timestamp": %d,
    "metadata": "%s",
    "description": "System configuration and metadata"
}]]

    local result = string.format(template, os.time(), encoded)
    logger.info("Generated JSON metadata steganography with %d bytes", #data)
    return result
end

function json_encoder.decode(json_content)
    logger.debug("Decoding JSON metadata steganography")

    if not json_content or json_content == "" then
        logger.warn("Empty JSON content")
        return ""
    end

    -- 记录原始内容以便调试
    logger.debug("Raw JSON content: %s", json_content)

    -- 提取 metadata 字段中的数据
    local encoded_data = json_content:match('"metadata":%s*"([^"]+)"')
    if not encoded_data then
        logger.warn("No metadata field found in JSON content")
        return ""
    end

    logger.debug("Found encoded data: %s", encoded_data)

    -- 尝试解码 Base64 数据
    local decoded = utils.base64_decode(encoded_data)
    if not decoded then
        logger.error("Failed to decode base64 data")
        return ""
    end

    logger.info("Successfully decoded %d bytes from JSON metadata", #decoded)
    return decoded
end

return json_encoder

local json_encoder = {}
local logger = require("rainbow.logger")
local utils = require("rainbow.utils")

function json_encoder.encode(data)
    logger.debug("Encoding data using JSON metadata steganography")

    if #data == 0 then
        return "{}"
    end

    -- 将数据编码为 Base64 并嵌入 JSON
    local encoded = utils.base64_encode(data)

    -- 构建 JSON 文档
    local template = [[
{
    "type": "metadata",
    "version": "1.0",
    "timestamp": %d,
    "metadata": "%s",
    "description": "System configuration and metadata"
}]]

    logger.info("Generated JSON metadata steganography with %d bytes", #data)
    return string.format(template, os.time(), encoded)
end

function json_encoder.decode(json_content)
    logger.debug("Decoding JSON metadata steganography")

    if not json_content or json_content == "" then
        return ""
    end

    -- 提取 metadata 字段中的数据
    local encoded_data = json_content:match('"metadata":%s*"([^"]+)"')
    if encoded_data then
        local decoded = utils.base64_decode(encoded_data)
        logger.info("Successfully decoded %d bytes from JSON metadata", #decoded)
        return decoded
    end

    logger.warn("No data found in JSON metadata")
    return ""
end

return json_encoder

local encoder = {}
local logger = require("rainbow.logger")

-- 编码器注册表
local encoders = {}

-- 注册编码器
function encoder.register(name, encode_func, decode_func)
    logger.debug("Registering encoder: %s", name)
    encoders[name] = {
        encode = encode_func,
        decode = decode_func
    }
end

-- 获取所有已注册的编码器名称
function encoder.get_encoders()
    local names = {}
    for name, _ in pairs(encoders) do
        table.insert(names, name)
    end
    return names
end

-- 编码数据
function encoder.encode(name, data)
    logger.debug("Encoding data with encoder: %s", name)
    local enc = encoders[name]
    if not enc then
        logger.warn("Encoder not found: %s", name)
        return nil
    end

    local result = enc.encode(data)
    if result then
        logger.info("Successfully encoded %d bytes with %s", #result, name)
    else
        logger.warn("Failed to encode data with %s", name)
    end
    return result
end

-- 解码数据
function encoder.decode(name, data)
    logger.debug("Decoding data with encoder: %s", name)
    local enc = encoders[name]
    if not enc then
        logger.warn("Encoder not found: %s", name)
        return nil
    end

    local result = enc.decode(data)
    if result then
        logger.info("Successfully decoded %d bytes with %s", #result, name)
    else
        logger.warn("Failed to decode data with %s", name)
    end
    return result
end

return encoder

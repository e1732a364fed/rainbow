local error_handler = {}

-- 错误类型定义
error_handler.ERROR_TYPE = {
    INVALID_DATA = "INVALID_DATA",
    COMPRESSION_ERROR = "COMPRESSION_ERROR",
    ENCODING_ERROR = "ENCODING_ERROR",
    DECODING_ERROR = "DECODING_ERROR",
    HANDSHAKE_ERROR = "HANDSHAKE_ERROR",
    PROTOCOL_ERROR = "PROTOCOL_ERROR",
    LENGTH_MISMATCH = "LENGTH_MISMATCH"
}

-- 错误消息模板
local error_messages = {
    [error_handler.ERROR_TYPE.INVALID_DATA] = "Invalid data format: %s",
    [error_handler.ERROR_TYPE.COMPRESSION_ERROR] = "Compression failed: %s",
    [error_handler.ERROR_TYPE.ENCODING_ERROR] = "Encoding failed: %s",
    [error_handler.ERROR_TYPE.DECODING_ERROR] = "Decoding failed: %s",
    [error_handler.ERROR_TYPE.HANDSHAKE_ERROR] = "Handshake failed: %s",
    [error_handler.ERROR_TYPE.PROTOCOL_ERROR] = "Protocol error: %s",
    [error_handler.ERROR_TYPE.LENGTH_MISMATCH] = "Length mismatch: expected %d, got %d"
}

-- 创建错误对象
function error_handler.create_error(error_type, ...)
    local args = { ... }
    local message

    if error_type == error_handler.ERROR_TYPE.LENGTH_MISMATCH then
        -- 对于长度不匹配错误，需要两个数字参数
        message = string.format(error_messages[error_type], tonumber(args[1]) or 0, tonumber(args[2]) or 0)
    else
        -- 对于其他错误，使用字符串参数
        message = string.format(error_messages[error_type], tostring(args[1] or "unknown error"))
    end

    return {
        type = error_type,
        message = message,
        timestamp = os.time()
    }
end

-- 检查是否是错误对象
function error_handler.is_error(obj)
    if type(obj) ~= "table" then return false end
    if not obj.type then return false end
    if not error_messages[obj.type] then return false end
    return true
end

-- 包装函数调用，处理错误
function error_handler.try(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        -- 从错误消息中提取实际的错误信息
        local error_msg = tostring(result):match(":%d+:%s*(.+)") or tostring(result)
        return error_handler.create_error(error_handler.ERROR_TYPE.PROTOCOL_ERROR, error_msg)
    end
    return result
end

return error_handler

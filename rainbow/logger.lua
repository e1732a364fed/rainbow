local logger = {}

-- 日志级别
logger.LEVEL = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3
}

-- 当前日志级别（默认为 DEBUG）
local current_level = logger.LEVEL.DEBUG

if Info_print == nil then
    Info_print = function(str)
        print("info", str)
    end
end

if Debug_print == nil then
    Debug_print = function(str)
        print("debug", str)
    end
end

if Warn_print == nil then
    Warn_print = function(str)
        print("warn", str)
    end
end


-- 设置日志级别
function logger.set_level(level)
    current_level = level
end

-- 基础日志函数
function logger.debug(message, ...)
    if current_level <= logger.LEVEL.DEBUG then
        Debug_print(string.format(message, ...))
    end
end

function logger.info(message, ...)
    if current_level <= logger.LEVEL.INFO then
        Info_print(string.format(message, ...))
    end
end

function logger.warn(message, ...)
    if current_level <= logger.LEVEL.WARN then
        Warn_print(string.format(message, ...))
    end
end

logger.error = logger.warn

return logger

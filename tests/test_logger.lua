local lu = require("luaunit")
local logger = require("rainbow.logger")

TestLogger = {}

function TestLogger:setUp()
    -- 保存原始的打印函数
    self.original_debug = Debug_print
    self.original_info = Info_print
    self.original_warn = Warn_print

    -- 创建测试用的日志收集器
    self.logs = {}
    Debug_print = function(str) table.insert(self.logs, { level = "debug", msg = str }) end
    Info_print = function(str) table.insert(self.logs, { level = "info", msg = str }) end
    Warn_print = function(str) table.insert(self.logs, { level = "warn", msg = str }) end
end

function TestLogger:tearDown()
    -- 恢复原始的打印函数
    Debug_print = self.original_debug
    Info_print = self.original_info
    Warn_print = self.original_warn
end

function TestLogger:test_log_levels()
    -- 确保使用默认的DEBUG级别开始测试
    logger.set_level(logger.LEVEL.DEBUG)

    -- 清空日志
    self.logs = {}

    -- 测试默认级别 (DEBUG)
    logger.debug("debug message")
    logger.info("info message")
    logger.warn("warn message")

    lu.assertEquals(#self.logs, 3)
    lu.assertEquals(self.logs[1].level, "debug")
    lu.assertEquals(self.logs[2].level, "info")
    lu.assertEquals(self.logs[3].level, "warn")

    -- 清空日志
    self.logs = {}

    -- 设置 INFO 级别
    logger.set_level(logger.LEVEL.INFO)
    logger.debug("debug message") -- 不应该记录
    logger.info("info message")
    logger.warn("warn message")

    lu.assertEquals(#self.logs, 2)
    lu.assertEquals(self.logs[1].level, "info")
    lu.assertEquals(self.logs[2].level, "warn")
end

function TestLogger:test_format_strings()
    -- 确保使用DEBUG级别以便能看到所有日志
    logger.set_level(logger.LEVEL.DEBUG)

    -- 初始化self.logs为空表
    self.logs = {}

    -- 测试debug级别的格式化
    logger.debug("Test %s %d", "string", 123)
    lu.assertEquals(self.logs[1].msg, "Test string 123")

    -- 测试info级别的格式化
    logger.info("Value: %.2f", 3.14159)
    lu.assertEquals(self.logs[2].msg, "Value: 3.14")
end

function TestLogger:test_error_alias()
    logger.error("error message")
    lu.assertEquals(self.logs[1].level, "warn")
    lu.assertEquals(self.logs[1].msg, "error message")
end

return TestLogger

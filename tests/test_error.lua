local lu = require("luaunit")
local error_handler = require("rainbow.error")

TestError = {}

function TestError:test_create_error()
    local err = error_handler.create_error(error_handler.ERROR_TYPE.INVALID_DATA, "test error")
    lu.assertNotNil(err)
    lu.assertEquals(err.type, error_handler.ERROR_TYPE.INVALID_DATA)
    lu.assertEquals(err.message, "Invalid data format: test error")
    lu.assertNotNil(err.timestamp)
end

function TestError:test_is_error()
    local err = error_handler.create_error(error_handler.ERROR_TYPE.COMPRESSION_ERROR, "test")
    lu.assertTrue(error_handler.is_error(err))

    -- 测试非错误对象
    lu.assertFalse(error_handler.is_error({}))
    lu.assertFalse(error_handler.is_error("string"))
    lu.assertFalse(error_handler.is_error(123))
end

function TestError:test_try()
    -- 测试成功的情况
    local result = error_handler.try(function() return "success" end)
    lu.assertEquals(result, "success")

    -- 测试失败的情况
    local err_result = error_handler.try(function() error("test error") end)
    lu.assertTrue(error_handler.is_error(err_result))
    lu.assertEquals(err_result.type, error_handler.ERROR_TYPE.PROTOCOL_ERROR)
    lu.assertEquals(err_result.message, "Protocol error: test error")
end

function TestError:test_error_types()
    -- 测试所有错误类型
    for type, _ in pairs(error_handler.ERROR_TYPE) do
        local err = error_handler.create_error(type, "test")
        lu.assertNotNil(err)
        lu.assertEquals(err.type, type)
        lu.assertNotNil(err.message)
        lu.assertNotNil(err.timestamp)
    end
end

return TestError

local lu = require("luaunit")
local encoder = require("rainbow.encoder")

TestEncoder = {}

function TestEncoder:setUp()
    -- 注册一个测试编码器
    encoder.register("test",
        function(data) return "encoded:" .. data end,
        function(data) return data:gsub("^encoded:", "") end
    )
end

function TestEncoder:test_register_and_get_encoders()
    local encoders = encoder.get_encoders()
    lu.assertNotNil(encoders)
    lu.assertTrue(#encoders > 0)
    lu.assertNotNil(table.concat(encoders, ","):find("test"))
end

function TestEncoder:test_encode()
    local data = "hello"
    local encoded = encoder.encode("test", data)
    lu.assertNotNil(encoded)
    lu.assertEquals(encoded, "encoded:hello")
end

function TestEncoder:test_decode()
    local encoded = "encoded:world"
    local decoded = encoder.decode("test", encoded)
    lu.assertNotNil(decoded)
    lu.assertEquals(decoded, "world")
end

function TestEncoder:test_invalid_encoder()
    local result = encoder.encode("non_existent", "data")
    lu.assertNil(result)

    result = encoder.decode("non_existent", "data")
    lu.assertNil(result)
end

return TestEncoder

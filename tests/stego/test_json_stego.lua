local lu = require("luaunit")
local json_stego = require("rainbow.stego.json_stego")

TestJsonStego = {}

function TestJsonStego:test_empty_data()
    local result = json_stego.encode("")
    lu.assertNotNil(result)
    lu.assertEquals(result, "{}")

    local decoded = json_stego.decode(result)
    lu.assertEquals(decoded, "")
end

function TestJsonStego:test_normal_data()
    local test_data = "Hello, World!"
    local result = json_stego.encode(test_data)
    lu.assertNotNil(result)
    lu.assertTrue(#result > 0)
    lu.assertStrContains(result, '"type": "metadata"')
    lu.assertStrContains(result, '"version": "1.0"')

    local decoded = json_stego.decode(result)
    lu.assertEquals(decoded, test_data)
end

function TestJsonStego:test_special_chars()
    local test_data = "Data with special chars: !@#$%^&*()"
    local result = json_stego.encode(test_data)
    lu.assertNotNil(result)

    local decoded = json_stego.decode(result)
    lu.assertEquals(decoded, test_data)
end

function TestJsonStego:test_invalid_input()
    local decoded = json_stego.decode(nil)
    lu.assertEquals(decoded, "")

    decoded = json_stego.decode("")
    lu.assertEquals(decoded, "")

    decoded = json_stego.decode('{"invalid": "json"}')
    lu.assertEquals(decoded, "")
end

return TestJsonStego

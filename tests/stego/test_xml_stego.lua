local lu = require("luaunit")
local xml_stego = require("rainbow.stego.xml_stego")

TestXmlStego = {}

function TestXmlStego:test_empty_data()
    local result = xml_stego.encode("")
    lu.assertNotNil(result)
    lu.assertTrue(#result > 0)
    lu.assertStrContains(result, '<?xml version="1.0"')

    local decoded = xml_stego.decode(result)
    lu.assertEquals(decoded, "")
end

function TestXmlStego:test_normal_data()
    local test_data = "Hello, World!"
    local result = xml_stego.encode(test_data)
    lu.assertNotNil(result)
    lu.assertTrue(#result > 0)
    lu.assertStrContains(result, "<configuration")
    lu.assertStrContains(result, "<![CDATA[")

    local decoded = xml_stego.decode(result)
    lu.assertEquals(decoded, test_data)
end

function TestXmlStego:test_special_chars()
    local test_data = "Data with XML special chars: < > & ' \""
    local result = xml_stego.encode(test_data)
    lu.assertNotNil(result)

    local decoded = xml_stego.decode(result)
    lu.assertEquals(decoded, test_data)
end

function TestXmlStego:test_invalid_input()
    local decoded = xml_stego.decode(nil)
    lu.assertEquals(decoded, "")

    decoded = xml_stego.decode("")
    lu.assertEquals(decoded, "")

    decoded = xml_stego.decode('<invalid>xml</invalid>')
    lu.assertEquals(decoded, "")
end

function TestXmlStego:test_random_properties()
    local test_data = "Test data"
    local result1 = xml_stego.encode(test_data)
    local result2 = xml_stego.encode(test_data)

    -- 确保每次生成的 XML 属性不同
    lu.assertNotEquals(result1, result2)

    -- 但解码结果应该相同
    local decoded1 = xml_stego.decode(result1)
    local decoded2 = xml_stego.decode(result2)
    lu.assertEquals(decoded1, decoded2)
    lu.assertEquals(decoded1, test_data)
end

return TestXmlStego

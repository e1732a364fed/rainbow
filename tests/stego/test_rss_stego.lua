local lu = require("luaunit")
local rss_stego = require("rainbow.stego.rss_stego")

TestRssStego = {}

function TestRssStego:test_empty_data()
    -- 测试编码空字符串
    local result = rss_stego.encode("")
    lu.assertNotNil(result)
    lu.assertTrue(#result > 0)
    lu.assertStrContains(result, '<?xml version="1.0"')
    lu.assertStrContains(result, '<rss version="2.0"')
    lu.assertStrContains(result, '<guid>')

    -- 解码应该返回空字符串
    local decoded = rss_stego.decode(result)
    lu.assertEquals(decoded, "")
end

function TestRssStego:test_normal_data()
    local test_data = "Hello, World!"
    local result = rss_stego.encode(test_data)
    lu.assertNotNil(result)
    lu.assertTrue(#result > 0)
    lu.assertStrContains(result, "<channel>")
    lu.assertStrContains(result, "<guid>")

    local decoded = rss_stego.decode(result)
    lu.assertEquals(decoded, test_data)
end

function TestRssStego:test_special_chars()
    local test_data = "Data with special chars: < > & ' \" 你好世界"
    local result = rss_stego.encode(test_data)
    lu.assertNotNil(result)
    lu.assertStrContains(result, "<guid>")

    local decoded = rss_stego.decode(result)
    lu.assertEquals(decoded, test_data)
end

function TestRssStego:test_invalid_input()
    -- 测试 nil 输入
    local decoded = rss_stego.decode(nil)
    lu.assertNil(decoded)

    -- 测试空字符串输入
    decoded = rss_stego.decode("")
    lu.assertNil(decoded)

    -- 测试无效的 XML
    decoded = rss_stego.decode('<invalid>xml</invalid>')
    lu.assertNil(decoded)

    -- 测试编码 nil 值（应该被转换为空字符串）
    local result = rss_stego.encode(nil)
    lu.assertNotNil(result)
    lu.assertStrContains(result, "<guid>")
    decoded = rss_stego.decode(result)
    lu.assertEquals(decoded, "")
end

function TestRssStego:test_timestamp()
    local test_data = "Test data"
    local result1 = rss_stego.encode(test_data)
    -- 等待一秒以确保时间戳不同
    os.execute("sleep 1")
    local result2 = rss_stego.encode(test_data)

    -- 确保每次生成的 RSS 时间戳不同
    lu.assertNotEquals(result1, result2)

    -- 但解码结果应该相同
    local decoded1 = rss_stego.decode(result1)
    local decoded2 = rss_stego.decode(result2)
    lu.assertEquals(decoded1, decoded2)
    lu.assertEquals(decoded1, test_data)
end

function TestRssStego:test_large_data()
    local test_data = string.rep("Large data test ", 1000)
    local result = rss_stego.encode(test_data)
    lu.assertNotNil(result)

    local decoded = rss_stego.decode(result)
    lu.assertEquals(decoded, test_data)
end

-- 运行测试
os.exit(lu.LuaUnit.run())

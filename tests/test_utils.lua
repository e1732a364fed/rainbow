local lu = require("luaunit")
local utils = require("rainbow.utils")

TestUtils = {}

-- 位运算测试
function TestUtils:testBitOperations()
    -- 测试 band (按位与)
    lu.assertEquals(utils.band(60, 13), 12) -- 60 = 111100, 13 = 001101, 结果应该是 001100 = 12
    lu.assertEquals(utils.band(255, 128), 128)
    lu.assertEquals(utils.band(0, 255), 0)

    -- 测试 rshift (右移)
    lu.assertEquals(utils.rshift(8, 1), 4)  -- 8 >> 1 = 4
    lu.assertEquals(utils.rshift(12, 2), 3) -- 12 >> 2 = 3
    lu.assertEquals(utils.rshift(1, 1), 0)

    -- 测试 lshift (左移)
    lu.assertEquals(utils.lshift(1, 3), 8) -- 1 << 3 = 8
    lu.assertEquals(utils.lshift(2, 2), 8) -- 2 << 2 = 8
    lu.assertEquals(utils.lshift(0, 5), 0)
end

-- Base64 编码解码测试
function TestUtils:testBase64()
    -- 测试基本的字符串
    local input = "Hello, World!"
    local encoded = utils.base64_encode(input)
    local decoded = utils.base64_decode(encoded)
    lu.assertEquals(decoded, input)

    -- 测试空字符串
    lu.assertEquals(utils.base64_decode(utils.base64_encode("")), "")

    -- 测试二进制数据
    local binary = string.char(0) .. string.char(255) .. string.char(128)
    encoded = utils.base64_encode(binary)
    decoded = utils.base64_decode(encoded)
    lu.assertEquals(decoded, binary)

    -- 测试填充
    local input1 = "a"   -- 需要两个等号填充
    local input2 = "ab"  -- 需要一个等号填充
    local input3 = "abc" -- 不需要填充
    lu.assertEquals(utils.base64_decode(utils.base64_encode(input1)), input1)
    lu.assertEquals(utils.base64_decode(utils.base64_encode(input2)), input2)
    lu.assertEquals(utils.base64_decode(utils.base64_encode(input3)), input3)
end

-- HTTP 头部生成测试
function TestUtils:testGenerateRealisticHeaders()
    local headers = utils.generate_realistic_headers()

    -- 验证必需的头部字段
    lu.assertNotNil(headers["User-Agent"])
    lu.assertNotNil(headers["Accept"])
    lu.assertNotNil(headers["Accept-Language"])
    lu.assertNotNil(headers["Accept-Encoding"])
    lu.assertNotNil(headers["Connection"])
    lu.assertNotNil(headers["Referer"])
    lu.assertNotNil(headers["Date"])

    -- 验证 User-Agent 格式
    lu.assertStrContains(headers["User-Agent"], "Mozilla/5.0")

    -- 验证日期格式
    local date = headers["Date"]
    lu.assertStrMatches(date, "%a+, %d+ %a+ %d+ %d+:%d+:%d+ GMT")
end

-- 随机延迟测试
function TestUtils:testRandomDelay()
    for _ = 1, 100 do
        local delay = utils.random_delay()
        lu.assertIsNumber(delay)
        lu.assertTrue(delay >= 50)  -- 最小延迟
        lu.assertTrue(delay <= 200) -- 最大延迟
    end
end

-- 随机数据包大小测试
function TestUtils:testRandomPacketSize()
    for _ = 1, 100 do
        local size = utils.random_packet_size()
        lu.assertIsNumber(size)
        lu.assertTrue(size >= 500)  -- 最小大小
        lu.assertTrue(size <= 1500) -- 最大大小
    end
end

-- 十六进制转储测试
function TestUtils:testHexDump()
    -- 测试基本字符串
    local str = "ABC"
    lu.assertEquals(utils.hex_dump(str), "41 42 43")

    -- 测试空字符串
    lu.assertEquals(utils.hex_dump(""), "<empty string>")

    -- 测试二进制数据
    local binary = string.char(0) .. string.char(255)
    lu.assertEquals(utils.hex_dump(binary), "00 FF")
end

function TestUtils:testHexDumpDetailed()
    -- 测试基本字符串
    local str = "Hello"
    local result = utils.hex_dump_detailed(str)
    lu.assertStrContains(result, "Length: 5 bytes")
    lu.assertStrContains(result, "48 65 6C 6C 6F") -- "Hello" 的十六进制
    lu.assertStrContains(result, "Hello")          -- ASCII 部分

    -- 测试包含不可打印字符的字符串
    local mixed = "Hi" .. string.char(0) .. "!"
    result = utils.hex_dump_detailed(mixed)
    lu.assertStrContains(result, "Length: 4 bytes")
    lu.assertStrContains(result, "Hi.!") -- 不可打印字符显示为点
end

return TestUtils

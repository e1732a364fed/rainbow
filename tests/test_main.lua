local lu = require("luaunit")
local rainbow = require("rainbow.main")
local stego = require("rainbow.stego")
local error_handler = require("rainbow.error")

TestMain = {}

function TestMain:setUp()
    -- 测试数据
    self.test_data = "Hello, Rainbow!"
    self.test_headers = {
        ["User-Agent"] = "Mozilla/5.0",
        ["Accept"] = "*/*"
    }
end

-- 测试握手包的编码和解码
function TestMain:test_handshake_encode_decode()
    -- 客户端编码
    local packets, lengths = rainbow.encode(self.test_data, true, rainbow.PACKET_TYPE.HANDSHAKE)
    lu.assertNotNil(packets)
    lu.assertNotNil(lengths)
    lu.assertTrue(#packets > 0)

    -- 验证基本头部
    for _, packet in ipairs(packets) do
        lu.assertStrContains(packet, "Content-Type:")
        lu.assertStrContains(packet, "Content-Length:")
    end

    -- 服务端解码
    local decoded = rainbow.decode(packets, false, rainbow.PACKET_TYPE.HANDSHAKE)
    lu.assertNotNil(decoded)
    lu.assertFalse(error_handler.is_error(decoded))
    lu.assertEquals(decoded, self.test_data)
end

-- 测试数据包的编码和解码
function TestMain:test_data_encode_decode()
    -- 客户端编码
    local packets, lengths = rainbow.encode(self.test_data, true, rainbow.PACKET_TYPE.DATA)
    lu.assertNotNil(packets)
    lu.assertNotNil(lengths)
    lu.assertTrue(#packets > 0)

    -- 验证基本头部
    for _, packet in ipairs(packets) do
        lu.assertStrContains(packet, "Content-Type:")
        lu.assertStrContains(packet, "Content-Length:")
    end

    -- 服务端解码
    local decoded = rainbow.decode(packets, false, rainbow.PACKET_TYPE.DATA)
    lu.assertNotNil(decoded)
    lu.assertFalse(error_handler.is_error(decoded))
    lu.assertEquals(decoded, self.test_data)
end

-- 测试长度验证功能
function TestMain:test_verify_length()
    local test_packet = [[HTTP/1.1 200 OK
Content-Type: text/plain
Content-Length: 5

Hello]]

    -- 正确长度验证
    lu.assertTrue(rainbow.verify_length(test_packet, 5))

    -- 错误长度验证
    lu.assertFalse(rainbow.verify_length(test_packet, 10))
end

-- 测试错误处理
function TestMain:test_error_handling()
    -- 测试无效输入
    local result = rainbow.encode(123, true, rainbow.PACKET_TYPE.DATA)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.INVALID_DATA)

    -- 测试无效数据包
    local result = rainbow.decode("invalid", true, rainbow.PACKET_TYPE.DATA)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.INVALID_DATA)
    lu.assertStrContains(result.message, "Invalid packet format")

    -- 测试解码失败
    local result = rainbow.decode({ "invalid packet" }, false, rainbow.PACKET_TYPE.DATA)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.DECODE_FAILED)
    lu.assertStrContains(result.message, "Packet 1:")
end

-- 添加新的测试函数：测试缺少 MIME 类型的情况
function TestMain:test_missing_mime_type()
    local invalid_packet = [[
HTTP/1.1 200 OK
Content-Length: 10

Test Data]]

    local result = rainbow.decode({ invalid_packet }, false, rainbow.PACKET_TYPE.DATA)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.DECODE_FAILED)
    lu.assertStrContains(result.message, "Invalid packet format")
end

-- 添加新的测试函数：测试缺少内容的情况
function TestMain:test_missing_content()
    local invalid_packet = [[
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 10]]

    local result = rainbow.decode({ invalid_packet }, false, rainbow.PACKET_TYPE.DATA)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.DECODE_FAILED)
    lu.assertStrContains(result.message, "Invalid packet format")
end

-- 添加新的测试函数：测试 Base64 解码失败的情况
function TestMain:test_base64_decode_failure()
    local invalid_packet = [[
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 10

Invalid!@#]]

    local result = rainbow.decode({ invalid_packet }, false, rainbow.PACKET_TYPE.HANDSHAKE)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.DECODE_FAILED)
    lu.assertStrContains(result.message, "Invalid packet format")
end

-- 添加新的测试函数：测试多个包的错误累积
function TestMain:test_multiple_packet_errors()
    local invalid_packets = {
        -- 格式无效的包
        [[HTTP/1.1 200 OK
Content-Length: 5
Hello]],
        -- 另一个格式无效的包
        [[HTTP/1.1 200 OK
Content-Type: text/html]],
        -- 完全错误的包
        "Not a HTTP packet"
    }

    local result = rainbow.decode(invalid_packets, false, rainbow.PACKET_TYPE.DATA)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.DECODE_FAILED)

    -- 验证每个包都报告了无效格式错误
    for i = 1, 3 do
        lu.assertStrContains(result.message, string.format("Packet %d: Invalid packet format", i))
    end
end

-- 添加新的测试函数：测试不支持的 MIME 类型
function TestMain:test_unsupported_mime_type()
    local invalid_packet = [[
HTTP/1.1 200 OK
Content-Type: application/unsupported
Content-Length: 10

Test Data]]

    local result = rainbow.decode({ invalid_packet }, false, rainbow.PACKET_TYPE.DATA)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.DECODE_FAILED)
    lu.assertStrContains(result.message, "Invalid packet format")
end

-- 测试不同 MIME 类型的编码和解码
function TestMain:test_different_mime_types()
    local data = "Test data for different MIME types"

    -- 编码和解码
    local packets, lengths = rainbow.encode(data, true, rainbow.PACKET_TYPE.DATA)
    lu.assertNotNil(packets)
    lu.assertTrue(#packets > 0)

    -- 验证基本头部
    for _, packet in ipairs(packets) do
        lu.assertStrContains(packet, "Content-Type:")
        lu.assertStrContains(packet, "Content-Length:")
    end

    -- 解码并验证
    local decoded = rainbow.decode(packets, false, rainbow.PACKET_TYPE.DATA)
    lu.assertNotNil(decoded)
    lu.assertFalse(error_handler.is_error(decoded))
    lu.assertEquals(decoded, data)
end

return TestMain

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

    -- 测试解码失败
    local result = rainbow.decode({ "invalid packet" }, false, rainbow.PACKET_TYPE.DATA)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.DECODE_FAILED)
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

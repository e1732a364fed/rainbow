local lu = require("luaunit")
local rainbow = require("rainbow.main")
local stego = require("rainbow.stego")
local error_handler = require("rainbow.error")
local logger = require("rainbow.logger")

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
    -- 客户端编码，使用 force_mime_type 指定 JSON
    local packets, lengths = rainbow.encode(self.test_data, true, "application/json")
    lu.assertNotNil(packets)
    lu.assertNotNil(lengths)
    lu.assertTrue(#packets > 0)

    -- 验证 Cookie 头部存在
    for _, packet in ipairs(packets) do
        lu.assertStrContains(packet, "Cookie:")
    end

    -- 服务端解码
    local decoded_parts = {}
    for i, packet in ipairs(packets) do
        local decoded, expected_length, is_read_end = rainbow.decode(packet, i, false)
        lu.assertNotNil(decoded)
        lu.assertNotNil(expected_length)
        lu.assertFalse(error_handler.is_error(decoded))
        table.insert(decoded_parts, decoded)
        if is_read_end then
            break
        end
    end
    local decoded = table.concat(decoded_parts)
    lu.assertEquals(decoded, self.test_data)
end

-- 测试数据包的编码和解码
function TestMain:test_data_encode_decode()
    local short_data = "Short test data"
    local packets, lengths = rainbow.encode(short_data, true)

    print("got", packets, lengths)
    lu.assertNotNil(packets)
    lu.assertNotNil(lengths)
    lu.assertTrue(#packets > 0)

    -- 验证 Cookie 头部存在
    for _, packet in ipairs(packets) do
        lu.assertStrContains(packet, "Cookie:")
    end

    -- 服务端解码
    local decoded_parts = {}
    for i, packet in ipairs(packets) do
        local decoded, expected_length, is_read_end = rainbow.decode(packet, i, false)
        lu.assertNotNil(decoded, "Failed to decode packet " .. i)
        lu.assertFalse(error_handler.is_error(decoded))
        table.insert(decoded_parts, decoded)
        if is_read_end then
            break
        end
    end
    local decoded = table.concat(decoded_parts)
    lu.assertEquals(decoded, short_data)

    -- 测试长数据
    local long_data = string.rep("Long test data ", 100)
    local packets, lengths = rainbow.encode(long_data, true)
    lu.assertNotNil(packets)
    lu.assertNotNil(lengths)
    lu.assertTrue(#packets > 0)

    -- 验证基本头部和 Cookie
    for _, packet in ipairs(packets) do
        lu.assertStrContains(packet, "POST")
        lu.assertStrContains(packet, "Content-Type:")
        lu.assertStrContains(packet, "Content-Length:")
        lu.assertStrContains(packet, "Cookie:")
    end

    -- 服务端解码
    local decoded_parts = {}
    for i, packet in ipairs(packets) do
        local decoded, expected_length, is_read_end = rainbow.decode(packet, i, false)
        lu.assertNotNil(decoded, string.format("Failed to decode packet %d", i))
        lu.assertFalse(error_handler.is_error(decoded))
        table.insert(decoded_parts, decoded)
        if is_read_end then
            break
        end
    end

    local decoded = table.concat(decoded_parts)
    lu.assertEquals(decoded, long_data)
end

-- 测试长度验证功能
function TestMain:test_verify_length()
    local test_packet = [[HTTP/1.1 200 OK
Content-Type: text/plain
Content-Length: 5

Hello]]

    lu.assertTrue(rainbow.verify_length(test_packet, 5))

    lu.assertFalse(rainbow.verify_length(test_packet, 10))
end

-- 测试错误处理
function TestMain:test_error_handling()
    -- 测试无效输入
    local result = rainbow.encode(123, true)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.INVALID_DATA)

    -- 测试无效数据包
    local result = rainbow.decode("invalid", 1, true)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.INVALID_DATA)
    lu.assertStrContains(result.message, "Invalid packet format")

    -- 测试解码失败
    local result = rainbow.decode("invalid packet", 1, false)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.INVALID_DATA)
end

-- 测试缺少 MIME 类型的情况
function TestMain:test_missing_mime_type()
    local invalid_packet = [[
HTTP/1.1 200 OK
Content-Length: 10
X-Total-Packets: 1
X-Expected-Length: 10

Test Data]]

    local result = rainbow.decode(invalid_packet, 1, false)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.INVALID_DATA)
end

-- 测试缺少内容的情况
function TestMain:test_missing_content()
    local invalid_packet = [[
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 10
X-Total-Packets: 1
X-Expected-Length: 10]]

    local result = rainbow.decode(invalid_packet, 1, false)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.INVALID_DATA)
end

-- 测试 Base64 解码失败的情况
function TestMain:test_base64_decode_failure()
    local invalid_packet = [[
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 10
X-Total-Packets: 1
X-Expected-Length: 10

Invalid!@#]]

    local result = rainbow.decode(invalid_packet, 1, false)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.INVALID_DATA)
end

-- 测试多个包的错误累积
function TestMain:test_multiple_packet_errors()
    local invalid_packet = "Not a HTTP packet"
    local result = rainbow.decode(invalid_packet, 1, false)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.INVALID_DATA)
end

-- 测试不支持的 MIME 类型
function TestMain:test_unsupported_mime_type()
    local invalid_packet = [[
HTTP/1.1 200 OK
Content-Type: application/unsupported
Content-Length: 10
X-Total-Packets: 1
X-Expected-Length: 10

Test Data]]

    local result = rainbow.decode(invalid_packet, 1, false)
    lu.assertTrue(error_handler.is_error(result))
    lu.assertEquals(result.code, error_handler.ERROR_TYPE.INVALID_DATA)
end

-- 测试不同 MIME 类型的编码和解码
function TestMain:test_different_mime_types()
    local test_data = string.rep("Test data for MIME type testing ", 50)
    local mime_types = {
        "text/html",
        "application/json",
        "application/xml"
    }

    for _, mime_type in ipairs(mime_types) do
        print(string.format("\n测试 MIME 类型: %s", mime_type))
        local packets, lengths = rainbow.encode(test_data, true, mime_type)

        lu.assertNotNil(packets)
        lu.assertTrue(#packets > 0)

        -- 验证所有数据包都使用了指定的 MIME 类型和 Cookie
        for _, packet in ipairs(packets) do
            lu.assertStrContains(packet, "Content-Type: " .. mime_type)
            lu.assertStrContains(packet, "Cookie:")
        end

        -- 解码并验证
        local decoded_parts = {}
        for i, packet in ipairs(packets) do
            local decoded, expected_length, is_read_end = rainbow.decode(packet, i, false)
            lu.assertNotNil(decoded)
            lu.assertFalse(error_handler.is_error(decoded))
            table.insert(decoded_parts, decoded)
            if is_read_end then
                break
            end
        end

        local decoded = table.concat(decoded_parts)
        lu.assertEquals(decoded, test_data)
    end
end

-- 测试所有可用的编码器
function TestMain:test_different_encoders()
    local test_data = "Test data for encoder testing"
    local encoders = {
        "html",
        "css",
        "prism",
        "font",
        "svg",
        "json",
        "xml",
        "rss"
        -- 注：audio 编码器可能需要特殊的二进制数据格式，暂时不测试
    }

    for _, encoder_name in ipairs(encoders) do
        -- 使用编码器名称进行编码
        local encoded = stego.encode_by_encoder(test_data, encoder_name)
        lu.assertNotNil(encoded,
            string.format("编码器 %s 编码失败", encoder_name))

        -- 使用对应的编码器实例进行解码
        local decoder = stego[encoder_name]
        local decoded = decoder.decode(encoded)
        lu.assertNotNil(decoded,
            string.format("编码器 %s 解码失败", encoder_name))

        -- 验证编解码结果
        lu.assertEquals(decoded, test_data,
            string.format("编码器 %s 的数据编解码不匹配", encoder_name))
    end
end

function TestMain:test_get_request_header_encoding()
    local short_data = "Short data for header encoding"
    local packets, lengths = rainbow.encode(short_data, true)
    lu.assertNotNil(packets)
    lu.assertNotNil(lengths)
    lu.assertTrue(#packets > 0)

    -- 验证 Cookie 头部存在
    for _, packet in ipairs(packets) do
        lu.assertStrContains(packet, "Cookie:")
    end

    -- 服务端解码
    local decoded_parts = {}
    for i, packet in ipairs(packets) do
        local decoded, expected_length, is_read_end = rainbow.decode(packet, i, false)
        lu.assertNotNil(decoded)
        lu.assertNotNil(expected_length)
        lu.assertEquals(expected_length, lengths[i])
        lu.assertFalse(error_handler.is_error(decoded))
        table.insert(decoded_parts, decoded)
        if is_read_end then
            break
        end
    end
    local decoded = table.concat(decoded_parts)
    lu.assertEquals(decoded, short_data)
end

return TestMain

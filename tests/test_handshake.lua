local lu = require("luaunit")
local handshake = require("rainbow.handshake")

TestHandshake = {}

function TestHandshake:test_encode_request()
    local target = "tcp://example.com:443"
    local requests, response_lengths = handshake.encode_request(target)

    -- 验证基本结构
    lu.assertNotNil(requests)
    lu.assertNotNil(response_lengths)
    lu.assertTrue(#requests > 0)
    lu.assertEquals(#requests, #response_lengths)

    -- 验证第一个请求的特殊性质
    local first = requests[1]
    lu.assertEquals(first.path, "/api/v1/session")
    lu.assertNotNil(first.headers["Cache-Control"])

    -- 验证后续请求
    for i = 2, #requests do
        local req = requests[i]
        lu.assertEquals(req.path, "/api/v1/data")
        lu.assertNotNil(req.headers)
        lu.assertNotNil(req.mime_type)
        lu.assertNotNil(req.content)
    end
end

function TestHandshake:test_decode_request()
    -- 创建一个模拟的请求序列
    local target = "tcp://example.com:443"
    local requests = handshake.encode_request(target)

    -- 解码请求
    local decoded_target = handshake.decode_request(requests)
    lu.assertEquals(decoded_target, target)
end

function TestHandshake:test_encode_response()
    -- 测试成功响应
    local success_responses, request_lengths = handshake.encode_response(true)
    lu.assertNotNil(success_responses)
    lu.assertNotNil(request_lengths)
    lu.assertTrue(#success_responses > 0)
    lu.assertEquals(#success_responses, #request_lengths)

    -- 测试错误响应
    local error_responses = handshake.encode_response(false, "test error")
    lu.assertNotNil(error_responses)
    for _, resp in ipairs(error_responses) do
        lu.assertNotNil(resp.mime_type)
        lu.assertNotNil(resp.content)
        lu.assertNotNil(resp.headers)
    end
end

function TestHandshake:test_decode_response()
    -- 测试成功响应的解码
    local success_responses = handshake.encode_response(true)
    local success_result = handshake.decode_response(success_responses)
    lu.assertTrue(success_result.success)
    lu.assertEquals(success_result.error_message, "")

    -- 测试错误响应的解码
    local error_responses = handshake.encode_response(false, "test error")
    local error_result = handshake.decode_response(error_responses)
    lu.assertFalse(error_result.success)
    lu.assertEquals(error_result.error_message, "test error")
end

return TestHandshake

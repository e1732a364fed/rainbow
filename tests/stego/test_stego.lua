local lu = require("luaunit")
local stego = require("rainbow.stego")

TestStego = {}

-- 测试所有编码器是否正确加载
function TestStego:testEncodersLoaded()
    lu.assertNotNil(stego.css)
    lu.assertNotNil(stego.prism)
    lu.assertNotNil(stego.font)
    lu.assertNotNil(stego.svg)
    lu.assertNotNil(stego.html)
    lu.assertNotNil(stego.json)
    lu.assertNotNil(stego.xml)
    lu.assertNotNil(stego.rss)
    lu.assertNotNil(stego.audio)
end

-- 测试 MIME 类型验证
function TestStego:testMimeTypeValidation()
    -- 测试有效的 MIME 类型
    lu.assertTrue(stego.is_valid_mime_type("text/html"))
    lu.assertTrue(stego.is_valid_mime_type("application/json"))
    lu.assertTrue(stego.is_valid_mime_type("application/xml"))
    lu.assertTrue(stego.is_valid_mime_type("audio/wav"))

    -- 测试无效的 MIME 类型
    lu.assertFalse(stego.is_valid_mime_type("invalid/type"))
    lu.assertFalse(stego.is_valid_mime_type("text/plain"))
end

-- 测试 MIME 类型对应的编码器
function TestStego:testMimeEncoders()
    -- 测试 text/html 的编码器
    local html_encoders = stego.get_mime_encoders("text/html")
    lu.assertNotNil(html_encoders)
    lu.assertEquals(#html_encoders, 5) -- html, prism, font, svg, css

    -- 测试 application/json 的编码器
    local json_encoders = stego.get_mime_encoders("application/json")
    lu.assertNotNil(json_encoders)
    lu.assertEquals(#json_encoders, 1) -- json

    -- 测试无效 MIME 类型的编码器
    local invalid_encoders = stego.get_mime_encoders("invalid/type")
    lu.assertNil(invalid_encoders)
end

-- 测试随机 MIME 类型选择
function TestStego:testRandomMimeType()
    local mime_type = stego.get_random_mime_type()
    lu.assertNotNil(mime_type)
    lu.assertTrue(stego.is_valid_mime_type(mime_type))
end

-- 测试编码和解码功能
function TestStego:testEncodeDecode()
    local test_data = "Hello, World!"
    local mime_types = { "text/html", "application/json", "application/xml" }

    for _, mime_type in ipairs(mime_types) do
        -- 测试编码
        local encoded, encoder = stego.encode_mime(test_data, mime_type)
        lu.assertNotNil(encoded, string.format("编码失败: %s", mime_type))
        lu.assertNotNil(encoder, string.format("没有返回编码器: %s", mime_type))

        -- 测试解码（使用相同的编码器）
        local decoded = stego.decode_mime(encoded, mime_type, encoder)
        lu.assertNotNil(decoded, string.format("解码失败: %s", mime_type))
        lu.assertEquals(decoded, test_data,
            string.format("编解码结果不匹配: %s", mime_type))
    end

    -- 测试无效 MIME 类型
    local result = stego.encode_mime(test_data, "invalid/type")
    lu.assertNil(result)

    result = stego.decode_mime("some content", "invalid/type")
    lu.assertNil(result)
end

os.exit(lu.LuaUnit.run())

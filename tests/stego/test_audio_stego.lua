local lu = require("luaunit")
local stego = require("rainbow.stego")

-- 测试音频隐写模块
TestAudioStego = {}

-- 测试基本的编码和解码功能
function TestAudioStego:test_basic_encode_decode()
    print("test_basic_encode_decode")
    local test_data = "Hello, Audio Steganography!"
    local encoded = stego.encode_mime(test_data, "audio/wav")

    -- 验证编码结果
    lu.assertNotNil(encoded, "编码结果不应为空")
    lu.assertString(encoded, "编码结果应该是字符串")
    lu.assertStrContains(encoded, "<audio", "编码结果应包含 audio 标签")
    lu.assertStrContains(encoded, "base64", "编码结果应包含 base64 数据")

    -- 测试解码
    local decoded = stego.decode_mime(encoded, "audio/wav")
    lu.assertNotNil(decoded, "解码结果不应为空")
    lu.assertEquals(decoded, test_data, "解码结果应与原始数据相同")
end

-- 测试空数据
function TestAudioStego:test_empty_data()
    print("test_empty_data")
    local test_data = ""
    local encoded = stego.encode_mime(test_data, "audio/wav")

    lu.assertNotNil(encoded, "空数据编码结果不应为空")

    local decoded = stego.decode_mime(encoded, "audio/wav")
    lu.assertNotNil(decoded, "空数据解码结果不应为空")
    lu.assertEquals(decoded, test_data, "空数据解码结果应为空字符串")
end

-- 测试长文本数据
function TestAudioStego:test_long_text()
    print("test_long_text")
    local test_data = string.rep("Long text test with repeated content. ", 30)
    local expected_data = test_data:sub(1, 1000) -- 只取前1000字节
    local encoded = stego.encode_mime(test_data, "audio/wav")

    lu.assertNotNil(encoded, "长文本编码结果不应为空")

    local decoded = stego.decode_mime(encoded, "audio/wav")
    lu.assertNotNil(decoded, "长文本解码结果不应为空")
    lu.assertEquals(#decoded, 1000, "解码结果长度应为1000字节")
    lu.assertEquals(decoded, expected_data, "长文本解码结果应与预期数据相同")
end

-- 测试二进制数据
function TestAudioStego:test_binary_data()
    print("test_binary_data")
    local test_data = string.char(0x00, 0xFF, 0x7F, 0x80, 0xAA, 0x55)
    local encoded = stego.encode_mime(test_data, "audio/wav")

    lu.assertNotNil(encoded, "二进制数据编码结果不应为空")

    local decoded = stego.decode_mime(encoded, "audio/wav")
    lu.assertNotNil(decoded, "二进制数据解码结果不应为空")
    lu.assertEquals(decoded, test_data, "二进制数据解码结果应与原始数据相同")
end

-- 测试特殊字符
function TestAudioStego:test_special_chars()
    print("test_special_chars")
    local test_data = "Special chars: !@#$%^&*()_+{}[]|\\:;\"'<>,.?/\n\t\r"
    local encoded = stego.encode_mime(test_data, "audio/wav")

    lu.assertNotNil(encoded, "特殊字符编码结果不应为空")

    local decoded = stego.decode_mime(encoded, "audio/wav")
    lu.assertNotNil(decoded, "特殊字符解码结果不应为空")
    lu.assertEquals(decoded, test_data, "特殊字符解码结果应与原始数据相同")
end

-- 测试 Unicode 字符
function TestAudioStego:test_unicode()
    print("test_unicode")
    local test_data = "Unicode测试：你好，世界！🌍✨🎵"
    local encoded = stego.encode_mime(test_data, "audio/wav")

    lu.assertNotNil(encoded, "Unicode编码结果不应为空")

    local decoded = stego.decode_mime(encoded, "audio/wav")
    lu.assertNotNil(decoded, "Unicode解码结果不应为空")
    lu.assertEquals(decoded, test_data, "Unicode解码结果应与原始数据相同")
end

-- 测试错误情况
function TestAudioStego:test_invalid_input()
    print("test_invalid_input")
    -- 测试无效的音频数据
    local invalid_audio = "<audio><source src=\"data:audio/wav;base64,invalid_base64\"></audio>"
    local decoded = stego.decode_mime(invalid_audio, "audio/wav")
    lu.assertNil(decoded, "无效音频数据应返回nil")

    -- 测试不完整的音频标签
    local incomplete_audio = "<audio><source src=\"data:audio/wav;base64,"
    local decoded_incomplete = stego.decode_mime(incomplete_audio, "audio/wav")
    lu.assertNil(decoded_incomplete, "不完整音频标签应返回nil")
end

-- 测试音频格式验证
function TestAudioStego:test_audio_format()
    print("test_audio_format")
    local test_data = "Audio format test"
    local encoded = stego.encode_mime(test_data, "audio/wav")

    -- 验证音频格式
    lu.assertStrContains(encoded, "audio/wav", "编码结果应指定正确的音频格式")
    lu.assertStrContains(encoded, "<source", "编码结果应包含source标签")
    lu.assertStrContains(encoded, "data:audio/wav;base64,", "编码结果应包含正确的数据URL前缀")
end

return TestAudioStego

local lu = require("luaunit")
local css = require("rainbow.css_stego").css_encoder
local utils = require("rainbow.utils")

TestCSSStego = {}

function TestCSSStego:setUp()
    print("setUp")
    -- 设置测试数据
    self.test_data = "Hello, World!"
    self.binary_data = string.char(0x00, 0xFF, 0x7F, 0x80) -- 测试边界情况
    self.empty_data = ""
    self.long_data = string.rep("Test", 100)               -- 测试长数据
end

function TestCSSStego:test_encode_decode()
    print("test_encode_decode")
    -- 测试基本的编码解码功能
    local encoded = css.encode(self.test_data)
    local decoded = css.decode(encoded)
    print("Original:", utils.hex_dump(self.test_data))
    print("Decoded:", utils.hex_dump(decoded))
    lu.assertEquals(decoded, self.test_data)
end

function TestCSSStego:test_binary_data()
    print("test_binary_data")
    -- 测试二进制数据的编码解码
    local encoded = css.encode(self.binary_data)
    local decoded = css.decode(encoded)
    print("Original:", utils.hex_dump(self.binary_data))
    print("Decoded:", utils.hex_dump(decoded))
    lu.assertEquals(decoded, self.binary_data)
end

function TestCSSStego:test_empty_data()
    print("test_empty_data")
    -- 测试空数据
    local encoded = css.encode(self.empty_data)
    local decoded = css.decode(encoded)
    lu.assertEquals(decoded, self.empty_data)
end

function TestCSSStego:test_long_data()
    print("test_long_data")
    -- 测试长数据
    local encoded = css.encode(self.long_data)
    local decoded = css.decode(encoded)
    print("Original length:", #self.long_data)
    print("Decoded length:", #decoded)
    lu.assertEquals(decoded, self.long_data)
end

function TestCSSStego:test_html_structure()
    print("test_html_structure")
    -- 测试生成的 HTML 结构是否正确
    local encoded = css.encode("test")
    -- 检查基本 HTML 结构
    lu.assertStrContains(encoded, "<!DOCTYPE html>")
    lu.assertStrContains(encoded, "<html>")
    lu.assertStrContains(encoded, "</html>")
    -- 检查是否包含必要的样式
    lu.assertStrContains(encoded, "<style>")
    lu.assertStrContains(encoded, "@keyframes")
    -- 检查是否包含动画延迟
    lu.assertStrContains(encoded, "animation-delay:")
end

function TestCSSStego:test_animation_structure()
    print("test_animation_structure")
    -- 测试生成的动画结构
    local encoded = css.encode("A") -- 单个字符测试
    -- 检查是否包含正确的动画属性
    lu.assertStrContains(encoded, "animation:")
    lu.assertStrContains(encoded, "opacity: 1")
    -- 检查延迟时间格式
    lu.assertStrMatches(encoded, "animation%-delay:%s*[%d%.]+s")
end

function TestCSSStego:test_decode_invalid_input()
    print("test_decode_invalid_input")
    -- 测试解码无效输入
    local invalid_html = "<div>Invalid HTML</div>"
    local decoded = css.decode(invalid_html)
    lu.assertEquals(decoded, "")

    -- 测试解码非CSS编码的HTML
    local normal_html = "<html><body><p>Normal HTML</p></body></html>"
    local decoded_normal = css.decode(normal_html)
    lu.assertEquals(decoded_normal, "")
end

function TestCSSStego:test_random_content()
    print("test_random_content")
    -- 测试随机内容的一致性
    local test_str = "Test String"
    local encoded1 = css.encode(test_str)
    local decoded1 = css.decode(encoded1)
    local encoded2 = css.encode(test_str)
    local decoded2 = css.decode(encoded2)

    -- 虽然编码结果可能不同（因为随机性），但解码结果应该相同
    lu.assertNotEquals(encoded1, encoded2) -- 编码应该不同
    lu.assertEquals(decoded1, test_str)    -- 解码应该正确
    lu.assertEquals(decoded2, test_str)    -- 解码应该正确
end

print("test file loaded")

Info_print = function(str)
    print("info", str)
end
Debug_print = function(str)
    print("debug", str)
end
Warn_print = function(str)
    print("warn", str)
end
-- 运行测试
os.exit(lu.LuaUnit.run())

local lu = require("luaunit")
local prism = require("rainbow.stego").prism

TestPrismStego = {}

function TestPrismStego:setUp()
    print("setUp")
    -- 设置测试数据
    self.test_data = "Hello, World!"
    self.binary_data = string.char(0x00, 0xFF, 0x7F, 0x80) -- 测试边界情况
    self.empty_data = ""
    self.long_data = string.rep("Test", 100)               -- 测试长数据
end

function TestPrismStego:test_encode_decode()
    print("test_encode_decode")
    -- 测试基本的编码解码功能
    local encoded = prism.encode(self.test_data)
    local decoded = prism.decode(encoded)
    lu.assertEquals(decoded, self.test_data)
end

function TestPrismStego:test_binary_data()
    print("test_binary_data")
    -- 测试二进制数据的编码解码
    local encoded = prism.encode(self.binary_data)
    local decoded = prism.decode(encoded)
    lu.assertEquals(decoded, self.binary_data)
end

function TestPrismStego:test_empty_data()
    -- 测试空数据
    local encoded = prism.encode(self.empty_data)
    local decoded = prism.decode(encoded)
    lu.assertEquals(decoded, self.empty_data)
end

function TestPrismStego:test_long_data()
    print("test_long_data")
    -- 测试长数据
    local encoded = prism.encode(self.long_data)
    local decoded = prism.decode(encoded)
    lu.assertEquals(decoded, self.long_data)
end

function TestPrismStego:test_html_structure()
    print("test_html_structure")
    -- 测试生成的 HTML 结构是否正确
    local encoded = prism.encode("test")
    -- 检查基本 HTML 结构
    lu.assertStrContains(encoded, "<!DOCTYPE html>")
    lu.assertStrContains(encoded, "<html>")
    lu.assertStrContains(encoded, "</html>")
    -- 检查是否包含必要的样式
    lu.assertStrContains(encoded, "<style>")
    lu.assertStrContains(encoded, ".content")
    -- 检查是否包含必要的类名
    lu.assertStrContains(encoded, "class='l")
end

function TestPrismStego:test_nested_tags()
    print("test_nested_tags")
    -- 测试嵌套标签的正确性
    local test_char = string.char(0) -- 将生成深度为1的嵌套
    local encoded = prism.encode(test_char)
    -- 检查是否只有一层嵌套
    local depth = 0
    for _ in encoded:gmatch("<div") do
        depth = depth + 1
    end
    lu.assertEquals(depth, 2) -- 1层嵌套 + 1个content div
end

function TestPrismStego:test_decode_invalid_input()
    print("test_decode_invalid_input")
    -- 测试解码无效输入
    local invalid_html = "<div>Invalid HTML"
    local decoded = prism.decode(invalid_html)
    lu.assertEquals(decoded, "")

    -- 测试解码非Prism编码的HTML
    local normal_html = "<html><body><p>Normal HTML</p></body></html>"
    local decoded_normal = prism.decode(normal_html)
    lu.assertEquals(decoded_normal, "")
end

function TestPrismStego:test_placeholder_text()
    print("test_placeholder_text")
    -- 测试占位文本是否正确插入
    local encoded = prism.encode("A")
    -- 检查是否包含预定义的占位文本之一
    local has_placeholder = false
    local placeholders = {
        "Latest updates",
        "More information",
        "Click here",
        "Learn more"
    }
    for _, text in ipairs(placeholders) do
        if encoded:find(text, 1, true) then
            has_placeholder = true
            break
        end
    end
    lu.assertTrue(has_placeholder)
end

return TestPrismStego

local lu = require("luaunit")
local font = require("rainbow.stego.font_stego")
local utils = require("rainbow.utils")

TestFontVariantStego = {}

function TestFontVariantStego:setUp()
    print("setUp")
    -- 设置测试数据
    self.test_data = "Hello, World!"
    self.binary_data = string.char(0x00, 0xFF, 0x7F, 0x80)
    self.empty_data = ""
    self.long_data = string.rep("Test", 100)
end

function TestFontVariantStego:test_encode_decode()
    print("test_encode_decode")
    local encoded = font.encode(self.test_data)
    local decoded = font.decode(encoded)
    print("Original:", utils.hex_dump(self.test_data))
    print("Decoded:", utils.hex_dump(decoded))
    lu.assertEquals(decoded, self.test_data)
end

function TestFontVariantStego:test_binary_data()
    print("test_binary_data")
    local encoded = font.encode(self.binary_data)
    local decoded = font.decode(encoded)
    lu.assertEquals(decoded, self.binary_data)
end

function TestFontVariantStego:test_empty_data()
    local encoded = font.encode(self.empty_data)
    local decoded = font.decode(encoded)
    lu.assertEquals(decoded, self.empty_data)
end

function TestFontVariantStego:test_font_structure()
    local encoded = font.encode("test")
    -- 检查基本结构
    lu.assertStrContains(encoded, "@font-face")
    lu.assertStrContains(encoded, "font-variation-settings")
    lu.assertStrContains(encoded, "Variable")
end

function TestFontVariantStego:test_variation_ranges()
    local encoded = font.encode(string.char(255)) -- 最大字节值
    -- 检查字体变体参数范围
    lu.assertStrContains(encoded, "font-weight: 100 900")
    lu.assertStrContains(encoded, "font-stretch: 25% 151%")
    lu.assertStrContains(encoded, "font-style: oblique 0deg 15deg")
end

return TestFontVariantStego

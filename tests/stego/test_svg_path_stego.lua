local lu = require("luaunit")
local svg = require("rainbow.svg_path_stego")
local utils = require("rainbow.utils")

TestSVGPathStego = {}

function TestSVGPathStego:setUp()
    print("setUp")
    -- 设置测试数据
    self.test_data = "Hello, World!"
    self.binary_data = string.char(0x00, 0xFF, 0x7F, 0x80)
    self.empty_data = ""
    self.long_data = string.rep("Test", 100)
end

function TestSVGPathStego:test_encode_decode()
    print("test_encode_decode")
    local encoded = svg.encode(self.test_data)
    local decoded = svg.decode(encoded)
    print("Original:", utils.hex_dump(self.test_data))
    print("Decoded:", utils.hex_dump(decoded))
    lu.assertEquals(decoded, self.test_data)
end

function TestSVGPathStego:test_binary_data()
    print("test_binary_data")
    local encoded = svg.encode(self.binary_data)
    local decoded = svg.decode(encoded)
    lu.assertEquals(decoded, self.binary_data)
end

function TestSVGPathStego:test_empty_data()
    local encoded = svg.encode(self.empty_data)
    local decoded = svg.decode(encoded)
    lu.assertEquals(decoded, self.empty_data)
end

function TestSVGPathStego:test_svg_structure()
    local encoded = svg.encode("test")
    lu.assertStrContains(encoded, "<svg")
    lu.assertStrContains(encoded, "viewBox")
    lu.assertStrContains(encoded, "<path")
    lu.assertStrContains(encoded, "<animate")
end

function TestSVGPathStego:test_path_attributes()
    local encoded = svg.encode("A")
    lu.assertStrContains(encoded, 'attributeName="d"')
    lu.assertStrContains(encoded, "dur=")
    lu.assertStrContains(encoded, "values=")
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
os.exit(lu.LuaUnit.run())

local lu = require("luaunit")
local HoudiniStego = require("rainbow.stego.houdini_stego")

TestHoudiniStego = {}

function TestHoudiniStego:setUp()
    self.test_data = "Hello, Houdini Stego!"
    self.complex_data = string.char(0x00, 0xFF, 0x7F, 0x80, 0xAA, 0x55)
end

-- 测试基本的隐写和提取功能
function TestHoudiniStego:test_hide_and_extract()
    local result = HoudiniStego.hide(self.test_data)

    -- 验证返回值包含所需的所有组件
    lu.assertNotNil(result.worklet)
    lu.assertNotNil(result.style)
    lu.assertNotNil(result.params)

    -- 验证能够正确提取数据
    local extracted = HoudiniStego.extract(result.params)
    lu.assertEquals(extracted, self.test_data)
end

-- 测试复杂二进制数据的处理
function TestHoudiniStego:test_complex_binary_data()
    local result = HoudiniStego.hide(self.complex_data)
    local extracted = HoudiniStego.extract(result.params)
    lu.assertEquals(extracted, self.complex_data)
end

-- 测试生成的 Worklet 代码格式
function TestHoudiniStego:test_worklet_code_format()
    local result = HoudiniStego.hide(self.test_data)

    -- 验证 Worklet 代码包含必要的组件
    lu.assertStrContains(result.worklet, "registerPaint")
    lu.assertStrContains(result.worklet, "StegoPainter")
    lu.assertStrContains(result.worklet, "--stego-params")
    lu.assertStrContains(result.worklet, "paint(ctx, size, properties)")
end

-- 测试生成的 CSS 样式格式
function TestHoudiniStego:test_css_style_format()
    local result = HoudiniStego.hide(self.test_data)

    -- 验证 CSS 样式包含必要的组件
    lu.assertStrContains(result.style, "@property --stego-params")
    lu.assertStrContains(result.style, ".stego-container")
    lu.assertStrContains(result.style, "background-image: paint(stego-pattern)")
end

-- 测试参数编码格式
function TestHoudiniStego:test_params_format()
    local result = HoudiniStego.hide(self.test_data)

    -- 验证每个参数都包含必要的属性
    for _, param in ipairs(result.params) do
        lu.assertNotNil(param.color)
        lu.assertStrMatches(param.color, "rgb%(%d+,%d+,%d+%)")
        lu.assertNotNil(param.offset)
        lu.assertNotNil(param.size)
    end
end

-- 测试空数据处理
function TestHoudiniStego:test_empty_data()
    local result = HoudiniStego.hide("")
    lu.assertNotNil(result)
    local extracted = HoudiniStego.extract(result.params)
    lu.assertEquals(extracted, "")
end

-- 测试长数据处理
function TestHoudiniStego:test_long_data()
    local long_data = string.rep("Long data test ", 100)
    local result = HoudiniStego.hide(long_data)
    local extracted = HoudiniStego.extract(result.params)
    lu.assertEquals(extracted, long_data)
end

-- 测试参数值范围
function TestHoudiniStego:test_param_value_ranges()
    local result = HoudiniStego.hide(self.complex_data)

    for _, param in ipairs(result.params) do
        -- 测试 RGB 值是否在有效范围内
        local r, g, b = param.color:match("rgb%((%d+),(%d+),(%d+)%)")
        r, g, b = tonumber(r), tonumber(g), tonumber(b)

        lu.assertIsTrue(r >= 0 and r <= 224)
        lu.assertIsTrue(g >= 0 and g <= 224)
        lu.assertIsTrue(b >= 0 and b <= 192)

        -- 测试 offset 和 size 是否在合理范围内
        lu.assertIsTrue(param.offset >= 0 and param.offset <= 1)
        lu.assertIsTrue(param.size > 0 and param.size <= 2.5)
    end
end

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

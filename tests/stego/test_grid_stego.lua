local lu = require("luaunit")
local GridStego = require("rainbow.stego.grid_stego")

TestGridStego = {}

function TestGridStego:setUp()
    self.stego = GridStego.new()
end

function TestGridStego:test_encode_decode()
    local test_data = { 65, 66, 67, 68, 69 } -- "ABCDE" 的 ASCII 值
    local encoded = self.stego:encode(test_data)

    -- 验证编码结果包含预期的 CSS 属性
    lu.assertStrContains(encoded, "display: grid")
    lu.assertStrContains(encoded, "gap:")
    lu.assertStrContains(encoded, "grid-template-areas:")

    -- 测试解码
    local decoded = self.stego:decode(encoded)
    lu.assertEquals(#decoded, #test_data)

    -- 验证解码后的数据与原始数据匹配
    for i = 1, #test_data do
        lu.assertEquals(decoded[i], test_data[i])
    end
end

function TestGridStego:test_detect()
    local test_data = { 65, 66, 67 }
    local encoded = self.stego:encode(test_data)

    -- 测试检测功能
    local result = self.stego:detect(encoded)
    lu.assertTrue(result)

    -- 测试对非隐写内容的检测
    local normal_css = [[
        .container {
            display: block;
            padding: 10px;
        }
    ]]
    lu.assertFalse(self.stego:detect(normal_css))
end

function TestGridStego:test_empty_input()
    local test_data = {}
    local encoded = self.stego:encode(test_data)
    local decoded = self.stego:decode(encoded)
    lu.assertEquals(#decoded, 0)
end

function TestGridStego:test_large_input()
    local test_data = {}
    for i = 1, 100 do -- 减少测试数据量，避免生成过大的 CSS
        test_data[i] = i % 256
    end

    local encoded = self.stego:encode(test_data)
    local decoded = self.stego:decode(encoded)

    lu.assertEquals(#decoded, #test_data)
    for i = 1, #test_data do
        lu.assertEquals(decoded[i], test_data[i])
    end
end

return TestGridStego

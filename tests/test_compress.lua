local lu = require("luaunit")
local compress = require("rainbow.compress")

TestCompress = {}

-- RLE 编码解码测试
function TestCompress:testRLEWithRepeatedChars()
    local input = "AAABBBCCCC"
    local encoded = compress.encode(input)
    local decoded = compress.decode(encoded)
    lu.assertEquals(decoded, input)
    lu.assertTrue(#encoded < #input)        -- 确保压缩后大小更小
    lu.assertEquals(encoded:sub(1, 1), "R") -- 确保使用了RLE算法
end

function TestCompress:testRLEWithNonRepeatedChars()
    local input = "ABCDEFG"
    local encoded = compress.encode(input)
    local decoded = compress.decode(encoded)
    lu.assertEquals(decoded, input)
    -- 对于不重复的字符，可能会使用无压缩模式
    lu.assertEquals(encoded:sub(1, 1), "N")
end

-- LZW 编码解码测试
function TestCompress:testLZWWithPatterns()
    -- 使用更长的重复模式，确保 LZW 压缩效果更好
    local input = string.rep("TOBEORNOTTOBE", 10) -- 重复更多次以确保压缩效果
    local encoded = compress.encode(input)
    local decoded = compress.decode(encoded)
    lu.assertEquals(decoded, input)
    lu.assertTrue(#encoded < #input) -- 现在应该能够压缩了
end

-- 边界情况测试
function TestCompress:testEmptyString()
    local input = ""
    local encoded = compress.encode(input)
    local decoded = compress.decode(encoded)
    lu.assertEquals(decoded, input)
end

function TestCompress:testSingleChar()
    local input = "A"
    local encoded = compress.encode(input)
    local decoded = compress.decode(encoded)
    lu.assertEquals(decoded, input)
end

function TestCompress:testLongRepeatedSequence()
    local input = string.rep("A", 1000)
    local encoded = compress.encode(input)
    local decoded = compress.decode(encoded)
    lu.assertEquals(decoded, input)
    lu.assertTrue(#encoded < #input)
end

function TestCompress:testBinaryData()
    local input = string.char(0) .. string.char(255) .. string.char(128)
    local encoded = compress.encode(input)
    local decoded = compress.decode(encoded)
    lu.assertEquals(decoded, input)
end

-- 错误处理测试
function TestCompress:testInvalidAlgorithmIdentifier()
    local result = compress.decode("X" .. "some data")
    lu.assertNil(result)
end

-- 运行测试
os.exit(lu.LuaUnit.run())

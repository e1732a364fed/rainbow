-- 移除 pl.class 依赖，使用原生 Lua 实现
-- local StegBase = require("rainbow.stego.init").StegBase

-- 创建 GridStego 类
local GridStego = {}
GridStego.__index = GridStego

-- 构造函数
function GridStego.new()
    local self = setmetatable({}, GridStego)
    self.name = "grid"
    self.description = "CSS Grid/Flex steganography"
    return self
end

-- 将字节数据编码为 CSS Grid/Flex 属性
-- @param bytes: 要编码的字节数据
-- @return: 包含编码后的 CSS 样式的字符串
function GridStego:encode(bytes)
    local css = {}
    local grid_template = {}

    -- 创建容器样式
    table.insert(css, ".stego-container {")
    table.insert(css, "  display: grid;")
    table.insert(css, "  grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));")

    -- 使用 grid-gap 和 grid-template-areas 编码数据
    local i = 1
    while i <= #bytes do
        -- 使用 gap 编码第一个字节
        local gap = bytes[i]
        table.insert(css, string.format("  gap: %dpx;", gap))

        -- 使用 grid-template-areas 编码第二个字节
        if i + 1 <= #bytes then
            local area_name = string.format("a%d", bytes[i + 1])
            table.insert(grid_template, string.format('"%s"', area_name))
        end

        i = i + 2
    end

    -- 添加 grid-template-areas
    if #grid_template > 0 then
        table.insert(css, "  grid-template-areas: " .. table.concat(grid_template, " ") .. ";")
    end
    table.insert(css, "}")

    return table.concat(css, "\n")
end

-- 从 CSS Grid/Flex 属性中解码数据
-- @param css: 包含编码数据的 CSS 样式字符串
-- @return: 解码后的字节数据
function GridStego:decode(css)
    local bytes = {}
    local gaps = {}
    local areas = {}

    -- 从 gap 值中提取数据
    for gap in css:gmatch("gap:%s*(%d+)px") do
        table.insert(gaps, tonumber(gap))
    end

    -- 从 grid-template-areas 中提取数据
    for area in css:gmatch('"a(%d+)"') do
        table.insert(areas, tonumber(area))
    end

    -- 按照编码时的顺序重建字节数组
    local j = 1
    for i = 1, #gaps do
        bytes[j] = gaps[i]
        if i <= #areas then
            bytes[j + 1] = areas[i]
        end
        j = j + 2
    end

    return bytes
end

-- 检查给定的数据是否可能包含隐写内容
-- @param css: 要检查的 CSS 样式字符串
-- @return: 如果可能包含隐写内容则返回 true
function GridStego:detect(css)
    -- 检查是否包含特定的 CSS Grid 属性组合
    if not css then return false end

    local has_grid = css:match("display:%s*grid") ~= nil
    local has_gap = css:match("gap:%s*%d+px") ~= nil
    local has_areas = css:match("grid%-template%-areas:") ~= nil

    return has_grid and has_gap and has_areas
end

return GridStego

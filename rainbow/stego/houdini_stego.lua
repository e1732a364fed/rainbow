local utils = require("rainbow.utils")

local HoudiniStego = {}

-- 将数据编码为 CSS Paint Worklet 参数
local function encode_to_paint_params(data)
    local bytes = { string.byte(data, 1, #data) }
    local params = {}

    for i, byte in ipairs(bytes) do
        -- 将每个字节转换为 RGB 颜色分量
        local r = utils.band(byte, 0xE0) / 32 -- 右移 5 位
        local g = utils.band(byte, 0x1C) / 4  -- 右移 2 位
        local b = utils.band(byte, 0x03)      -- 保持原值

        -- 将颜色分量转换为画布参数
        table.insert(params, {
            color = string.format("rgb(%d,%d,%d)",
                r * 32, -- 0-7 映射到 0-224
                g * 32, -- 0-7 映射到 0-224
                b * 64  -- 0-3 映射到 0-192
            ),
            offset = i * 0.1,
            size = 1 + (i % 3) * 0.5
        })
    end

    return params
end

-- 从 CSS Paint Worklet 参数中解码数据
local function decode_from_paint_params(params)
    local bytes = {}

    for _, param in ipairs(params) do
        local r, g, b = param.color:match("rgb%((%d+),(%d+),(%d+)%)")
        r = math.floor(tonumber(r) / 32)
        g = math.floor(tonumber(g) / 32)
        b = math.floor(tonumber(b) / 64)

        -- 重构字节
        local byte = utils.band(utils.lshift(r, 5), 0xFF)
        byte = utils.band(byte + utils.lshift(g, 2), 0xFF)
        byte = utils.band(byte + b, 0xFF)
        table.insert(bytes, byte)
    end

    return string.char(table.unpack(bytes))
end

-- 将表转换为 JSON 字符串的简单实现
local function table_to_json(t)
    if type(t) ~= "table" then
        if type(t) == "string" then
            return string.format('"%s"', t)
        else
            return tostring(t)
        end
    end

    local parts = {}
    -- 检查是否是数组
    local is_array = true
    local n = #t
    for k, _ in pairs(t) do
        if type(k) ~= "number" or k > n then
            is_array = false
            break
        end
    end

    if is_array then
        for _, v in ipairs(t) do
            table.insert(parts, table_to_json(v))
        end
        return "[" .. table.concat(parts, ",") .. "]"
    else
        for k, v in pairs(t) do
            table.insert(parts, string.format('"%s":%s', k, table_to_json(v)))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
end

-- 生成 CSS Paint Worklet 代码
local function generate_paint_worklet(params)
    local worklet_code = [[
if (typeof registerPaint !== 'undefined') {
    class StegoPainter {
        static get inputProperties() {
            return ['--stego-params'];
        }

        paint(ctx, size, properties) {
            const params = JSON.parse(properties.get('--stego-params'));
            params.forEach(param => {
                ctx.fillStyle = param.color;
                const x = size.width * param.offset;
                const y = size.height * param.offset;
                const s = param.size;
                ctx.fillRect(x, y, s, s);
            });
        }
    }
    registerPaint('stego-pattern', StegoPainter);
}
]]
    return worklet_code
end

-- 生成使用 Paint Worklet 的 CSS 样式
local function generate_css_style(params)
    local json_str = table_to_json(params)
    return string.format([[
@property --stego-params {
    syntax: '*';
    inherits: false;
    initial-value: '%s';
}
.stego-container {
    --stego-params: '%s';
    background-image: paint(stego-pattern);
}]], json_str, json_str)
end

-- 隐写数据
function HoudiniStego.hide(data)
    local params = encode_to_paint_params(data)
    return {
        worklet = generate_paint_worklet(params),
        style = generate_css_style(params),
        params = params
    }
end

-- 提取数据
function HoudiniStego.extract(params)
    return decode_from_paint_params(params)
end

return HoudiniStego

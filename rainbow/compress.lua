local compress = {}
local logger = require("rainbow.logger")

-- 简单的游程编码 (RLE)
local function rle_encode(data)
    local result = {}
    local count = 1
    local prev = data:sub(1, 1)

    for i = 2, #data do
        local curr = data:sub(i, i)
        if curr == prev and count < 255 then
            count = count + 1
        else
            table.insert(result, string.char(count))
            table.insert(result, prev)
            count = 1
            prev = curr
        end
    end

    -- 处理最后一个字符
    table.insert(result, string.char(count))
    table.insert(result, prev)

    return table.concat(result)
end

local function rle_decode(data)
    local result = {}
    local i = 1

    while i <= #data do
        local count = data:byte(i)
        local char = data:sub(i + 1, i + 1)
        for _ = 1, count do
            table.insert(result, char)
        end
        i = i + 2
    end

    return table.concat(result)
end

-- LZW 压缩算法
local function lzw_encode(data)
    local dict = {}
    local result = {}
    local sequence = {}
    local next_code = 256

    -- 初始化字典
    for i = 0, 255 do
        dict[string.char(i)] = i
    end

    local current = data:sub(1, 1)
    for i = 2, #data do
        local char = data:sub(i, i)
        local combined = current .. char

        if dict[combined] then
            current = combined
        else
            table.insert(sequence, dict[current])
            dict[combined] = next_code
            next_code = next_code + 1
            current = char
        end
    end

    -- 处理最后一个字符串
    if current then
        table.insert(sequence, dict[current])
    end

    -- 将编码序列转换为字节序列
    for _, code in ipairs(sequence) do
        table.insert(result, string.char(math.floor(code / 256)))
        table.insert(result, string.char(code % 256))
    end

    return table.concat(result)
end

local function lzw_decode(data)
    local dict = {}
    local sequence = {}
    local result = {}
    local next_code = 256

    -- 初始化字典
    for i = 0, 255 do
        dict[i] = string.char(i)
    end

    -- 将字节序列转换回编码序列
    for i = 1, #data, 2 do
        local high = data:byte(i) or 0
        local low = data:byte(i + 1) or 0
        table.insert(sequence, high * 256 + low)
    end

    local old = sequence[1]
    table.insert(result, dict[old])

    for i = 2, #sequence do
        local new = sequence[i]
        local entry

        if dict[new] then
            entry = dict[new]
        elseif new == next_code then
            entry = dict[old] .. dict[old]:sub(1, 1)
        else
            return nil -- 错误的压缩数据
        end

        table.insert(result, entry)
        dict[next_code] = dict[old] .. entry:sub(1, 1)
        next_code = next_code + 1
        old = new
    end

    return table.concat(result)
end

-- 压缩数据，返回压缩后的数据和使用的算法标识
function compress.encode(data)
    logger.debug("Starting compression of %d bytes", #data)

    -- 尝试两种压缩算法，选择压缩率更好的
    local rle_data = rle_encode(data)
    local lzw_data = lzw_encode(data)

    local result
    if #rle_data < #lzw_data and #rle_data < #data then
        logger.info("Using RLE compression: %d -> %d bytes", #data, #rle_data)
        result = "R" .. rle_data
    elseif #lzw_data < #data then
        logger.info("Using LZW compression: %d -> %d bytes", #data, #lzw_data)
        result = "L" .. lzw_data
    else
        logger.info("No compression applied (no size benefit)")
        result = "N" .. data
    end

    return result
end

-- 解压数据
function compress.decode(data)
    local algorithm = data:sub(1, 1)
    local compressed = data:sub(2)

    logger.debug("Decompressing data with algorithm: %s", algorithm)

    local result
    if algorithm == "R" then
        result = rle_decode(compressed)
    elseif algorithm == "L" then
        result = lzw_decode(compressed)
    elseif algorithm == "N" then
        result = compressed
    else
        logger.warn("Unknown compression algorithm: %s", algorithm)
        return nil
    end

    if result then
        logger.info("Successfully decompressed %d bytes", #result)
    end

    return result
end

return compress

local sequence = {}
local logger = require("rainbow.logger")

-- 将数据分片成指定大小的块
function sequence.split_data(data, chunk_size)
    logger.debug("Splitting data into chunks of size %d", chunk_size)
    local chunks = {}
    for i = 1, #data, chunk_size do
        table.insert(chunks, data:sub(i, i + chunk_size - 1))
    end
    logger.debug("Created %d chunks", #chunks)
    return chunks
end

-- 生成随机的响应长度序列
function sequence.generate_response_lengths(count)
    logger.debug("Generating %d response lengths", count)
    local lengths = {}
    for i = 1, count do
        -- 生成一个看起来像正常 HTTP 响应的长度
        local base_length = 200                      -- 基础 HTTP 响应头的大小
        local random_content = math.random(300, 800) -- 随机内容长度
        table.insert(lengths, base_length + random_content)
    end
    return lengths
end

-- 生成读写序列
function sequence.generate_sequence(data, is_write)
    logger.debug("Generating sequence: write=%s, data_length=%d", tostring(is_write), #data)
    local chunks = sequence.split_data(data, 64) -- 每个数据块64字节
    local response_lengths = sequence.generate_response_lengths(#chunks)

    local write_sequence = {}
    local read_sequence = {}

    -- 根据是写入还是读取来决定哪个序列包含实际数据
    if is_write then
        write_sequence = chunks
        read_sequence = response_lengths
        logger.info("Generated write sequence with %d chunks", #chunks)
    else
        write_sequence = response_lengths
        read_sequence = chunks
        logger.info("Generated read sequence with %d chunks", #chunks)
    end

    return write_sequence, read_sequence
end

-- 合并序列中的数据
function sequence.merge_sequence(sequence_data)
    logger.debug("Merging sequence with %d parts", #sequence_data)
    local result = table.concat(sequence_data)
    logger.debug("Merged sequence length: %d", #result)
    return result
end

return sequence

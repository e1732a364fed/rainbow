local utils = {}
local logger = require("rainbow.logger")

-- 生成随机的 HTTP 头部
function utils.generate_realistic_headers()
    logger.debug("Generating realistic HTTP headers")
    local user_agents = {
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }

    local referers = {
        "https://www.google.com",
        "https://www.bing.com",
        "https://www.yahoo.com"
    }

    -- 生成真实的时间戳
    local function get_http_date()
        return os.date("!%a, %d %b %Y %H:%M:%S GMT")
    end

    local headers = {
        ["User-Agent"] = user_agents[math.random(#user_agents)],
        ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        ["Accept-Language"] = "en-US,en;q=0.5",
        ["Accept-Encoding"] = "gzip, deflate, br",
        ["Connection"] = "keep-alive",
        ["Referer"] = referers[math.random(#referers)],
        ["Date"] = get_http_date()
    }

    logger.debug("Generated headers with %d fields", #headers)
    return headers
end

-- 随机化延迟函数
function utils.random_delay()
    local min_delay = 50  -- 最小延迟 50ms
    local max_delay = 200 -- 最大延迟 200ms
    local delay = math.random(min_delay, max_delay)
    logger.debug("Generated random delay: %dms", delay)
    return delay
end

-- 生成随机的数据包大小
function utils.random_packet_size()
    local min_size = 500
    local max_size = 1500
    local size = math.random(min_size, max_size)
    logger.debug("Generated random packet size: %d bytes", size)
    return size
end

return utils

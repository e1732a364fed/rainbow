local xml_encoder = {}
local logger = require("rainbow.logger")
local utils = require("rainbow.utils")

-- 添加模块名称
xml_encoder.name = "xml"

function xml_encoder.encode(data)
    logger.debug("Encoding data using XML steganography")
    -- 创建一个看起来像配置文件的 XML 结构
    local xml_template = [=[
<?xml version="1.0" encoding="UTF-8"?>
<configuration timestamp="%d">
    <settings>
        <property name="%s" value="%s"/>
        <property name="theme" value="default"/>
        <property name="language" value="en"/>
    </settings>
    <data><![CDATA[%s]]></data>
</configuration>]=]

    -- 生成随机的属性名
    local random_prop = "prop_" .. tostring(math.random(1000, 9999))

    -- 生成随机的可见值
    local visible_values = {
        "enabled", "disabled", "auto", "manual", "default"
    }
    local random_value = visible_values[math.random(#visible_values)]

    -- Base64 编码数据
    local encoded_data = utils.base64_encode(data)
    logger.info("Generated XML with CDATA length: %d", #encoded_data)

    local result = string.format(xml_template,
        os.time(),
        random_prop,
        random_value,
        encoded_data
    )

    logger.debug("Generated XML content:\n%s", result)
    return result
end

function xml_encoder.decode(xml_content)
    logger.debug("Decoding XML steganography")

    if not xml_content or xml_content == "" then
        logger.warn("Empty or nil XML content")
        return ""
    end

    logger.debug("XML content to decode:\n%s", xml_content)
    -- 从 CDATA 部分提取 Base64 编码的数据
    local encoded_data = xml_content:match("<data><!%[CDATA%[(.-)%]%]></data>")
    if not encoded_data then
        logger.warn("No CDATA section found in XML")
        return ""
    end

    logger.debug("Found encoded data: %s", encoded_data)
    local decoded_data = utils.base64_decode(encoded_data)
    if decoded_data then
        logger.info("Successfully decoded %d bytes from XML", #decoded_data)
    end
    return decoded_data or ""
end

return xml_encoder

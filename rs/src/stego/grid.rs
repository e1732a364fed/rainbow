use crate::Result;
use regex::Regex;
use tracing::{debug, info};

/// 将字节数据编码为 CSS Grid/Flex 属性
pub fn encode(data: &[u8]) -> Result<Vec<u8>> {
    debug!("Encoding data using CSS Grid/Flex steganography");

    if data.is_empty() {
        return Ok(Vec::new());
    }

    let mut css = Vec::new();
    let mut grid_template = Vec::new();

    // 创建容器样式
    css.push(".stego-container {".to_string());
    css.push("  display: grid;".to_string());
    css.push("  grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));".to_string());

    // 使用 grid-gap 和 grid-template-areas 编码数据
    let mut i = 0;
    while i < data.len() {
        // 使用 gap 编码第一个字节
        let gap = data[i];
        css.push(format!("  gap: {}px;", gap));

        // 使用 grid-template-areas 编码第二个字节
        if i + 1 < data.len() {
            let area_name = format!("a{}", data[i + 1]);
            grid_template.push(format!("\"{}\"", area_name));
        }

        i += 2;
    }

    // 添加 grid-template-areas
    if !grid_template.is_empty() {
        css.push(format!(
            "  grid-template-areas: {};",
            grid_template.join(" ")
        ));
    }
    css.push("}".to_string());

    info!("Generated CSS Grid/Flex styles with {} bytes", data.len());
    Ok(css.join("\n").into_bytes())
}

/// 从 CSS Grid/Flex 属性中解码数据
pub fn decode(data: &[u8]) -> Result<Vec<u8>> {
    debug!("Decoding CSS Grid/Flex steganography");

    if data.is_empty() {
        return Ok(Vec::new());
    }

    let css = String::from_utf8_lossy(data);
    let mut bytes = Vec::new();

    // 从 gap 值中提取数据
    let gap_re = Regex::new(r"gap:\s*(\d+)px").unwrap();
    let gaps: Vec<u8> = gap_re
        .captures_iter(&css)
        .filter_map(|cap| cap[1].parse().ok())
        .collect();

    // 从 grid-template-areas 中提取数据
    let area_re = Regex::new(r#""a(\d+)""#).unwrap();
    let areas: Vec<u8> = area_re
        .captures_iter(&css)
        .filter_map(|cap| cap[1].parse().ok())
        .collect();

    // 按照编码时的顺序重建字节数组
    for i in 0..gaps.len() {
        bytes.push(gaps[i]);
        if i < areas.len() {
            bytes.push(areas[i]);
        }
    }

    info!(
        "Successfully decoded {} bytes from CSS Grid/Flex styles",
        bytes.len()
    );
    Ok(bytes)
}

/// 检查给定的数据是否可能包含隐写内容
pub fn detect(data: &[u8]) -> bool {
    if data.is_empty() {
        return false;
    }

    let css = String::from_utf8_lossy(data);
    let has_grid = css.contains("display: grid");
    let has_gap = Regex::new(r"gap:\s*\d+px").unwrap().is_match(&css);
    let has_areas = css.contains("grid-template-areas:");

    has_grid && has_gap && has_areas
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_grid() {
        let test_data = b"Hello, Grid Steganography!";
        let encoded = encode(test_data).unwrap();
        assert!(!encoded.is_empty());
        let decoded = decode(&encoded).unwrap();
        assert_eq!(decoded, test_data);
    }

    #[test]
    fn test_empty_data() {
        let test_data = b"";
        let encoded = encode(test_data).unwrap();
        assert!(encoded.is_empty());
        let decoded = decode(&encoded).unwrap();
        assert!(decoded.is_empty());
    }

    #[test]
    fn test_large_data() {
        let test_data: Vec<u8> = (0..2000).map(|i| (i % 256) as u8).collect();
        let encoded = encode(&test_data).unwrap();
        let decoded = decode(&encoded).unwrap();
        assert!(!decoded.is_empty());
    }

    #[test]
    fn test_invalid_input() {
        let result = decode(b"").unwrap();
        assert!(result.is_empty());
        let result = decode(b"invalid content").unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn test_detect() {
        let test_data = b"Hello, Grid!";
        let encoded = encode(test_data).unwrap();
        assert!(detect(&encoded));
        assert!(!detect(b"Regular CSS content"));
    }
}

use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use rand::Rng;
use tracing::{debug, info};

use crate::Result;

const MIN_LAYERS: usize = 20;
const MAX_LAYERS: usize = 250;

/// 使用 HTML 嵌套 div 进行编码
pub fn encode(data: &[u8]) -> Result<Vec<u8>> {
    let encoded = BASE64.encode(data);
    debug!("Encoding {} bytes using Prism steganography", data.len());

    let mut rng = rand::thread_rng();
    let mut html = String::new();

    // 添加 HTML 头部
    html.push_str("<!DOCTYPE html>\n<html>\n<head>\n<title>Page Title</title>\n</head>\n<body>\n");
    html.push_str("    <div class=\"container\">\n");

    // 为每个字符创建一个嵌套的 div 结构
    for c in encoded.chars() {
        let layers = rng.gen_range(MIN_LAYERS..=MAX_LAYERS);
        let mut div = String::new();

        // 创建嵌套的 div 结构
        for i in 1..=layers {
            div.push_str(&format!("<div class=\"l{}\">", i));
        }

        // 添加字符
        div.push(c);

        // 关闭所有 div
        for _ in 1..=layers {
            div.push_str("</div>");
        }

        html.push_str("        ");
        html.push_str(&div);
        html.push('\n');
    }

    // 添加 HTML 尾部
    html.push_str("    </div>\n</body>\n</html>\n");

    info!(
        "Generated Prism steganography with {} nested divs",
        encoded.len()
    );
    Ok(html.into_bytes())
}

/// 从 HTML 嵌套 div 中解码数据
pub fn decode(data: &[u8]) -> Result<Vec<u8>> {
    let html = String::from_utf8_lossy(data);
    debug!("Decoding Prism steganography from {} bytes", data.len());

    let mut encoded = String::new();

    // 提取每个嵌套 div 结构中的字符
    for line in html.lines() {
        let line = line.trim();
        if line.starts_with("<div class=\"l1\">") {
            // 找到最内层的文本内容
            let mut depth = 0;
            let mut in_tag = false;
            let mut found_char = None;

            for (i, c) in line.chars().enumerate() {
                match c {
                    '<' => {
                        in_tag = true;
                        if line[i..].starts_with("<div") {
                            depth += 1;
                        } else if line[i..].starts_with("</div") {
                            depth -= 1;
                        }
                    }
                    '>' => {
                        in_tag = false;
                    }
                    c if !in_tag && depth > 0 && !c.is_whitespace() => {
                        found_char = Some(c);
                        break;
                    }
                    _ => {}
                }
            }

            if let Some(c) = found_char {
                encoded.push(c);
            }
        }
    }

    if encoded.is_empty() {
        return Ok(Vec::new());
    }

    // Base64 解码
    match BASE64.decode(&encoded) {
        Ok(decoded) => {
            info!(
                "Successfully decoded {} bytes from Prism steganography",
                decoded.len()
            );
            Ok(decoded)
        }
        Err(_) => Ok(Vec::new()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_prism() {
        let test_data = b"Hello, Prism Steganography!";
        let encoded = encode(test_data).unwrap();
        assert!(!encoded.is_empty());
        let decoded = decode(&encoded).unwrap();
        assert_eq!(decoded, test_data);
    }

    #[test]
    fn test_empty_data() {
        let test_data = b"";
        let encoded = encode(test_data).unwrap();
        assert!(!encoded.is_empty());
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
}

use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use rand::seq::SliceRandom;

use crate::Result;

const HTML_TEMPLATES: &[&str] = &[
    r#"<!DOCTYPE html>
<html>
<head>
    <title>Welcome</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
    <div class="container">
        <h1>Welcome to our site</h1>
        <p>This is a sample page.</p>
        <!-- {data} -->
    </div>
</body>
</html>"#,
    r#"<!DOCTYPE html>
<html>
<head>
    <title>Blog</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
    <article>
        <h1>Latest News</h1>
        <section>
            <!-- {data} -->
            <p>Stay tuned for more updates!</p>
        </section>
    </article>
</body>
</html>"#,
];

/// 将数据编码到 HTML 注释中
pub fn encode(data: &[u8]) -> Result<Vec<u8>> {
    // 处理空数据的情况
    if data.is_empty() {
        return Ok(b"<!DOCTYPE html><html><head></head><body></body></html>".to_vec());
    }

    let template = HTML_TEMPLATES.choose(&mut rand::thread_rng()).unwrap();
    let encoded = BASE64.encode(data);

    // 确保编码后的数据不包含 "--" 序列
    let safe_encoded = encoded.replace("--", "-&#45;");
    let html = template.replace("{data}", &safe_encoded);

    Ok(html.into_bytes())
}

/// 从 HTML 注释中解码数据
pub fn decode(data: &[u8]) -> Result<Vec<u8>> {
    let html = String::from_utf8_lossy(data);

    if html.is_empty() {
        return Ok(Vec::new());
    }

    // 查找注释中的数据，使用更严格的模式匹配
    if let Some(start) = html.find("<!-- ") {
        if let Some(end) = html[start..].find(" -->") {
            let encoded = &html[start + 5..start + end];

            // 还原可能被转义的 "--" 序列
            let restored = encoded.replace("-&#45;", "--");

            if let Ok(decoded) = BASE64.decode(restored) {
                return Ok(decoded);
            }
        }
    }

    // 如果无法解码，返回空向量而不是原始数据
    Ok(Vec::new())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_html() {
        let test_data = b"Hello, HTML Steganography!";
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

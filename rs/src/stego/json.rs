use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use chrono::Utc;
use serde_json::{json, Value};
use tracing::{debug, info, warn};

use crate::Result;

/// 将数据编码到 JSON 元数据中
pub fn encode(data: &[u8]) -> Result<Vec<u8>> {
    debug!("Encoding data using JSON metadata steganography");

    if data.is_empty() {
        return Ok(b"{}".to_vec());
    }

    // 将数据编码为 Base64
    let encoded = BASE64.encode(data);

    // 构建 JSON 文档
    let json_obj = json!({
        "type": "metadata",
        "version": "1.0",
        "timestamp": Utc::now().timestamp(),
        "metadata": encoded,
        "description": "System configuration and metadata"
    });

    info!(
        "Generated JSON metadata steganography with {} bytes",
        data.len()
    );
    Ok(serde_json::to_vec(&json_obj)?)
}

/// 从 JSON 元数据中解码数据
pub fn decode(json_content: &[u8]) -> Result<Vec<u8>> {
    debug!("Decoding JSON metadata steganography");

    if json_content.is_empty() {
        warn!("Empty JSON content");
        return Ok(Vec::new());
    }

    // 记录原始内容以便调试
    debug!(
        "Raw JSON content: {}",
        String::from_utf8_lossy(json_content)
    );

    // 解析 JSON
    let json_obj: Value = serde_json::from_slice(json_content)?;

    // 提取 metadata 字段中的数据
    if let Some(encoded_data) = json_obj.get("metadata").and_then(|v| v.as_str()) {
        debug!("Found encoded data: {}", encoded_data);

        // 尝试解码 Base64 数据
        if let Ok(decoded) = BASE64.decode(encoded_data) {
            info!(
                "Successfully decoded {} bytes from JSON metadata",
                decoded.len()
            );
            return Ok(decoded);
        }
    }

    warn!("No metadata field found in JSON content");
    Ok(Vec::new())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_json() {
        let test_data = b"Hello, JSON Steganography!";
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
        let result = decode(b"invalid content");
        assert!(result.is_err() || result.unwrap().is_empty());
    }
}

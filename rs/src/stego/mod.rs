pub mod audio;
pub mod css;
pub mod font;
pub mod grid;
pub mod houdini;
pub mod html;
pub mod json;
pub mod prism;
pub mod rss;
pub mod svg_path;
pub mod xml;

use async_trait::async_trait;
use rand::Rng;
use tracing::{debug, warn};

use crate::Result;
use audio::AudioEncoder;

#[async_trait]
pub trait Encoder {
    fn name(&self) -> &'static str;
    async fn encode(&self, data: &[u8]) -> Result<String>;
    async fn decode(&self, content: &str) -> Result<Vec<u8>>;
}

const MIME_TYPES: &[(&str, &[&str])] = &[
    ("text/html", &["html", "prism", "font"]),
    ("text/css", &["css", "houdini", "grid"]),
    ("application/json", &["json"]),
    ("application/xml", &["xml", "rss"]),
    ("audio/wav", &["audio"]),
    ("image/svg+xml", &["svg_path"]),
];

/// 获取随机的 MIME 类型
pub fn get_random_mime_type() -> String {
    let (mime_type, _) = MIME_TYPES[rand::thread_rng().gen_range(0..MIME_TYPES.len())];
    mime_type.to_string()
}

/// 根据 MIME 类型编码数据
pub async fn encode_mime(data: &[u8], mime_type: &str) -> Result<Vec<u8>> {
    debug!("Encoding data with MIME type: {}", mime_type);

    match mime_type {
        "text/html" => {
            // 随机选择 HTML、Prism 或 Font 编码器
            let choice = rand::thread_rng().gen_range(0..3);
            match choice {
                0 => html::encode(data),
                1 => prism::encode(data),
                _ => font::encode(data),
            }
        }
        "text/css" => {
            // 随机选择 CSS、Houdini 或 Grid 编码器
            let choice = rand::thread_rng().gen_range(0..3);
            match choice {
                0 => css::encode(data),
                1 => houdini::encode(data),
                _ => grid::encode(data),
            }
        }
        "application/json" => json::encode(data),
        "application/xml" => {
            // 随机选择 XML 或 RSS 编码器
            if rand::thread_rng().gen_bool(0.5) {
                xml::encode(data)
            } else {
                rss::encode(data)
            }
        }
        "audio/wav" => {
            let encoder = AudioEncoder::default();
            let encoded = encoder.encode(data).await?;
            Ok(encoded.into_bytes())
        }
        "image/svg+xml" => svg_path::encode(data),
        _ => {
            warn!("Unsupported MIME type: {}", mime_type);
            Ok(data.to_vec())
        }
    }
}

/// 根据 MIME 类型解码数据
pub async fn decode_mime(data: &[u8], mime_type: &str) -> Result<Vec<u8>> {
    debug!("Decoding data with MIME type: {}", mime_type);

    match mime_type {
        "text/html" => {
            // 尝试 HTML、Prism 和 Font 解码
            match html::decode(data) {
                Ok(decoded) if !decoded.is_empty() => Ok(decoded),
                _ => match prism::decode(data) {
                    Ok(decoded) if !decoded.is_empty() => Ok(decoded),
                    _ => font::decode(data),
                },
            }
        }
        "text/css" => {
            // 尝试 CSS、Houdini 和 Grid 解码
            match css::decode(data) {
                Ok(decoded) if !decoded.is_empty() => Ok(decoded),
                _ => match houdini::decode(data) {
                    Ok(decoded) if !decoded.is_empty() => Ok(decoded),
                    _ => grid::decode(data),
                },
            }
        }
        "application/json" => json::decode(data),
        "application/xml" => {
            // 尝试 XML 解码，如果失败则尝试 RSS 解码
            match xml::decode(data) {
                Ok(decoded) if !decoded.is_empty() => Ok(decoded),
                _ => rss::decode(data),
            }
        }
        "audio/wav" => {
            let encoder = AudioEncoder::default();
            let content = String::from_utf8(data.to_vec())?;
            encoder.decode(&content).await
        }
        "image/svg+xml" => svg_path::decode(data),
        _ => {
            warn!("Unsupported MIME type: {}", mime_type);
            Ok(data.to_vec())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // async fn test_encoder<T: Encoder>(encoder: T, test_data: &[u8]) {
    //     // 编码
    //     let encoded = encoder.encode(test_data).await.unwrap();
    //     assert!(!encoded.is_empty());

    //     // 解码
    //     let decoded = encoder.decode(&encoded).await.unwrap();
    //     assert_eq!(decoded, test_data);
    // }

    #[tokio::test]
    async fn test_mime_type_encoding() {
        let test_data = b"Hello, MIME Type Steganography!";

        // 测试所有 MIME 类型
        for (mime_type, _) in MIME_TYPES {
            let encoded = encode_mime(test_data, mime_type).await.unwrap();
            let decoded = decode_mime(&encoded, mime_type).await.unwrap();
            assert_eq!(decoded, test_data);
        }
    }

    #[tokio::test]
    async fn test_random_mime_type() {
        let mime_type = get_random_mime_type();
        assert!(MIME_TYPES.iter().any(|(mt, _)| *mt == mime_type));
    }

    #[tokio::test]
    async fn test_unsupported_mime_type() {
        let test_data = b"Hello, Unsupported MIME Type!";
        let encoded = encode_mime(test_data, "unsupported/type").await.unwrap();
        let decoded = decode_mime(&encoded, "unsupported/type").await.unwrap();
        assert_eq!(decoded, test_data);
    }

    #[tokio::test]
    async fn test_empty_data_mime() {
        let test_data = b"";
        for (mime_type, _) in MIME_TYPES {
            let encoded = encode_mime(test_data, mime_type).await.unwrap();
            let decoded = decode_mime(&encoded, mime_type).await.unwrap();
            assert!(decoded.is_empty());
        }
    }

    #[tokio::test]
    async fn test_large_data_mime() {
        let test_data: Vec<u8> = (0..2000).map(|i| (i % 256) as u8).collect();
        for (mime_type, _) in MIME_TYPES {
            let encoded = encode_mime(&test_data, mime_type).await.unwrap();
            let decoded = decode_mime(&encoded, mime_type).await.unwrap();
            assert!(!decoded.is_empty());
        }
    }
}

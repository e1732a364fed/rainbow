use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::Result;

#[derive(Debug, Serialize, Deserialize)]
struct PaintParam {
    color: String,
    offset: f64,
    size: f64,
}

/// 将数据编码为 CSS Paint Worklet 参数
fn encode_to_paint_params(data: &[u8]) -> Vec<PaintParam> {
    let mut params = Vec::new();

    for (i, &byte) in data.iter().enumerate() {
        // 修正：直接使用位移运算获取颜色分量
        let r = (byte & 0xE0) >> 5; // 不变，取高3位
        let g = (byte & 0x1C) >> 2; // 不变，取中3位
        let b = byte & 0x03; // 不变，取低2位

        params.push(PaintParam {
            color: format!(
                "rgb({},{},{})",
                r * 32, // 正确：0-7 映射到 0-224
                g * 32, // 正确：0-7 映射到 0-224
                b * 64  // 正确：0-3 映射到 0-192
            ),
            offset: (i as f64) * 0.1,
            size: 1.0 + (i % 3) as f64 * 0.5,
        });
    }

    params
}

/// 从 CSS Paint Worklet 参数中解码数据
fn decode_from_paint_params(params: &[PaintParam]) -> Vec<u8> {
    let mut bytes = Vec::new();

    for param in params {
        let rgb_values: Vec<u8> = param
            .color
            .trim_start_matches("rgb(")
            .trim_end_matches(')')
            .split(',')
            .filter_map(|s| s.trim().parse::<u32>().ok())
            .map(|v| v as u8)
            .collect();

        if rgb_values.len() == 3 {
            // 修正：先将 RGB 值映射回原始比例
            let r = rgb_values[0] / 32; // 0-224 映射回 0-7
            let g = rgb_values[1] / 32; // 0-224 映射回 0-7
            let b = rgb_values[2] / 64; // 0-192 映射回 0-3

            // 修正：使用位运算重构字节
            let byte = (r << 5) | (g << 2) | b;
            bytes.push(byte);
        }
    }

    bytes
}

/// 生成 CSS Paint Worklet 代码
fn generate_paint_worklet() -> String {
    r#"if (typeof registerPaint !== 'undefined') {
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
}"#
    .to_string()
}

/// 生成使用 Paint Worklet 的 CSS 样式
fn generate_css_style(params: &[PaintParam]) -> Result<String> {
    let json_str = serde_json::to_string(params)?;
    Ok(format!(
        r#"@property --stego-params {{
    syntax: '*';
    inherits: false;
    initial-value: '{}';
}}
.stego-container {{
    --stego-params: '{}';
    background-image: paint(stego-pattern);
}}"#,
        json_str, json_str
    ))
}

/// 将数据编码到 CSS Paint Worklet 中
pub fn encode(data: &[u8]) -> Result<Vec<u8>> {
    let params = encode_to_paint_params(data);
    let worklet = generate_paint_worklet();
    let style = generate_css_style(&params)?;

    let output = json!({
        "worklet": worklet,
        "style": style,
        "params": params,
    });

    Ok(serde_json::to_vec(&output)?)
}

/// 从 CSS Paint Worklet 中解码数据
pub fn decode(data: &[u8]) -> Result<Vec<u8>> {
    if data.is_empty() {
        return Ok(Vec::new());
    }

    let json = match serde_json::from_slice::<serde_json::Value>(data) {
        Ok(v) => v,
        Err(_) => return Ok(Vec::new()),
    };

    if let Some(params) = json.get("params") {
        let params: Vec<PaintParam> = match serde_json::from_value(params.clone()) {
            Ok(v) => v,
            Err(_) => return Ok(Vec::new()),
        };
        Ok(decode_from_paint_params(&params))
    } else {
        Ok(Vec::new())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_houdini() {
        let test_data = b"Hello, Houdini Steganography!";
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

    #[test]
    fn test_paint_param_encoding() {
        let test_data = b"Test";
        let params = encode_to_paint_params(test_data);
        assert!(!params.is_empty());
        let decoded = decode_from_paint_params(&params);
        assert_eq!(decoded, test_data);
    }
}

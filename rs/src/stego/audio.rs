use crate::stego::Encoder;
use crate::Result;
use async_trait::async_trait;
use base64::{engine::general_purpose, Engine as _};
use std::f64::consts::PI;
use tracing::{debug, warn};

pub struct AudioEncoder {
    sample_rate: u32,
    carrier_freq: u32,
    frame_size: usize,
    sync_size: usize,
    sync_amplitude: f64,
    amplitude_step: f64,
}

impl Default for AudioEncoder {
    fn default() -> Self {
        Self {
            sample_rate: 8000,
            carrier_freq: 1000,
            frame_size: 32,
            sync_size: 64,
            sync_amplitude: 0.9,
            amplitude_step: 1.0 / 256.0,
        }
    }
}

impl AudioEncoder {
    fn generate_sync_sequence(&self) -> Vec<f64> {
        (0..self.sync_size)
            .map(|i| {
                if i % 2 == 0 {
                    self.sync_amplitude
                } else {
                    -self.sync_amplitude
                }
            })
            .collect()
    }

    fn byte_to_amplitude(&self, byte: u8) -> f64 {
        (byte as f64 + 1.0) * self.amplitude_step
    }

    fn amplitude_to_byte(&self, amplitude: f64) -> u8 {
        let byte = (amplitude / self.amplitude_step - 0.5).floor() as i32;
        byte.clamp(0, 255) as u8
    }

    fn generate_audio_data(&self, data: &[u8]) -> Vec<f64> {
        let mut samples = Vec::new();
        let mut phase = 0.0;
        let time_step = 1.0 / self.sample_rate as f64;

        // 添加同步序列
        samples.extend(self.generate_sync_sequence());

        // 编码数据
        for &byte in data {
            let amplitude = self.byte_to_amplitude(byte);

            // 生成一帧数据
            for _ in 0..self.frame_size {
                let sample = amplitude * (2.0 * PI * self.carrier_freq as f64 * phase).sin();
                samples.push(sample);
                phase += time_step;
            }

            // 在字节之间添加短暂的静音
            samples.extend(std::iter::repeat(0.0).take(4));
        }

        samples
    }

    fn calculate_peak_amplitude(frame: &[f64]) -> f64 {
        frame.iter().map(|&x| x.abs()).fold(0.0, f64::max)
    }

    fn extract_data(&self, samples: &[f64]) -> Option<Vec<u8>> {
        let mut data = Vec::new();
        let mut pos = 0;
        let sync_sequence = self.generate_sync_sequence();

        // 寻找同步序列
        let mut sync_detected = false;
        'outer: while pos <= samples.len().saturating_sub(self.sync_size) {
            let mut match_found = true;
            for i in 0..self.sync_size {
                let expected = sync_sequence[i];
                let actual = samples[pos + i];
                if (actual.abs() - expected.abs()).abs() > 0.1 * expected.abs() {
                    match_found = false;
                    break;
                }
            }

            if match_found {
                sync_detected = true;
                pos += self.sync_size;
                break 'outer;
            }
            pos += 1;
        }

        if !sync_detected {
            return None;
        }

        // 解码数据
        let frame_size = self.frame_size + 4; // 包括静音间隔
        while pos + self.frame_size <= samples.len() {
            let frame: Vec<f64> = samples[pos..pos + self.frame_size].to_vec();
            let amplitude = Self::calculate_peak_amplitude(&frame);

            if amplitude > self.amplitude_step / 2.0 {
                let byte = self.amplitude_to_byte(amplitude);
                data.push(byte);
            }

            pos += frame_size;
        }

        Some(data)
    }
}

#[async_trait]
impl Encoder for AudioEncoder {
    fn name(&self) -> &'static str {
        "audio"
    }

    async fn encode(&self, data: &[u8]) -> Result<String> {
        debug!("Encoding data using Web Audio API stego");

        if data.is_empty() {
            return Ok(String::from(
                "<audio id=\"stego-audio\" style=\"display:none\"></audio>",
            ));
        }

        let data = if data.len() > 1000 {
            warn!("Data too long, truncating to 1000 bytes");
            &data[..1000]
        } else {
            data
        };

        // 生成音频波形
        let audio_data = self.generate_audio_data(data);

        // 将音频数据转换为字符串
        let audio_str = audio_data
            .iter()
            .map(|x| x.to_string())
            .collect::<Vec<_>>()
            .join(",");

        // Base64 编码
        let encoded = general_purpose::STANDARD.encode(audio_str);

        Ok(format!(
            "<audio id=\"stego-audio\" style=\"display:none\">\
            <source src=\"data:audio/wav;base64,{}\" type=\"audio/wav\">\
            </audio>",
            encoded
        ))
    }

    async fn decode(&self, content: &str) -> Result<Vec<u8>> {
        debug!("Decoding data from Web Audio API stego");

        if content.is_empty() {
            warn!("Empty audio content");
            return Ok(Vec::new());
        }

        if content
            .trim()
            .matches(|c| c == '<' || c == '>' || c == ' ')
            .count()
            == content.trim().len()
        {
            debug!("Empty audio element found");
            return Ok(Vec::new());
        }

        // 提取 Base64 编码的音频数据
        let base64_data = match content
            .split("base64,")
            .nth(1)
            .and_then(|s| s.split('"').next())
        {
            Some(data) => data,
            None => {
                warn!("No audio data found in content");
                return Ok(Vec::new());
            }
        };

        // 解码 Base64 数据
        let decoded = match general_purpose::STANDARD.decode(base64_data) {
            Ok(data) => data,
            Err(e) => {
                warn!("Failed to decode base64 audio data: {}", e);
                return Ok(Vec::new());
            }
        };

        let decoded_str = match String::from_utf8(decoded) {
            Ok(s) => s,
            Err(e) => {
                warn!("Failed to convert decoded data to string: {}", e);
                return Ok(Vec::new());
            }
        };

        // 将解码后的数据转换为样本数组
        let samples: Vec<f64> = decoded_str
            .split(',')
            .filter_map(|s| s.parse().ok())
            .collect();

        if samples.is_empty() {
            warn!("No valid audio samples found");
            return Ok(Vec::new());
        }

        // 从音频波形中提取数据
        match self.extract_data(&samples) {
            Some(data) => {
                debug!("Successfully decoded {} bytes from audio", data.len());
                Ok(data)
            }
            None => {
                warn!("Failed to extract data from audio samples");
                Ok(Vec::new())
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_audio() {
        let encoder = AudioEncoder::default();
        let test_data = b"Hello, Audio Steganography!";

        // 编码
        let encoded = encoder.encode(test_data).await.unwrap();
        assert!(!encoded.is_empty());

        // 解码
        let decoded = encoder.decode(&encoded).await.unwrap();
        assert_eq!(decoded, test_data);
    }

    #[tokio::test]
    async fn test_empty_data() {
        let encoder = AudioEncoder::default();
        let test_data = b"";

        // 编码
        let encoded = encoder.encode(test_data).await.unwrap();
        assert!(!encoded.is_empty());

        // 解码
        let decoded = encoder.decode(&encoded).await.unwrap();
        assert!(decoded.is_empty());
    }

    #[tokio::test]
    async fn test_large_data() {
        let encoder = AudioEncoder::default();
        let test_data: Vec<u8> = (0..2000).map(|i| (i % 256) as u8).collect();

        // 编码
        let encoded = encoder.encode(&test_data).await.unwrap();
        assert!(!encoded.is_empty());

        // 解码
        let decoded = encoder.decode(&encoded).await.unwrap();
        assert!(!decoded.is_empty());
    }

    #[tokio::test]
    async fn test_invalid_input() {
        let encoder = AudioEncoder::default();

        // 测试空字符串
        let result = encoder.decode("").await.unwrap();
        assert!(result.is_empty());

        // 测试无效内容
        let result = encoder.decode("invalid content").await.unwrap();
        assert!(result.is_empty());
    }
}

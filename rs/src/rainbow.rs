/*!
 * Rainbow module implements core steganography and data hiding functionality.
 *
 * This module provides capabilities for:
 * - Encoding and decoding hidden messages in network traffic
 * - Managing HTTP request/response steganography
 * - Generating randomized traffic patterns
 * - Handling base64 and other encoding schemes
 */

use async_trait::async_trait;
use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use chrono::Utc;
use rand::Rng;
use reqwest::header::{HeaderMap, HeaderValue, COOKIE};
use serde::{Deserialize, Serialize};
use tracing::{debug, info};

use crate::{
    stego::{self, get_random_mime_type},
    utils::{generate_realistic_headers, validate_http_packet, HTTP_CONSTANTS},
    DecodeResult, EncodeResult, NetworkSteganographyProcessor, RainbowError, Result,
};

const CHUNK_SIZE: usize = 1024;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct PacketInfo {
    version: u8,
    timestamp: i64,
    index: usize,
    total: usize,
    length: usize,
}

impl PacketInfo {
    fn new(index: usize, total: usize, length: usize) -> Self {
        Self {
            version: 1,
            timestamp: Utc::now().timestamp(),
            index,
            total,
            length,
        }
    }

    fn to_cookie(&self) -> Result<String> {
        let json = serde_json::to_string(self)?;
        Ok(BASE64.encode(json.as_bytes()))
    }

    fn from_cookie(cookie: &str) -> Result<Self> {
        let bytes = BASE64.decode(cookie)?;
        let json = String::from_utf8_lossy(&bytes);
        Ok(serde_json::from_str(&json)?)
    }
}

/// An implementation of [`NetworkSteganographyProcessor`]
#[derive(Debug, Clone)]
pub struct Rainbow;

impl Rainbow {
    pub fn new() -> Self {
        Self
    }

    fn parse_cookies(headers: &HeaderMap) -> Vec<String> {
        headers
            .get_all(COOKIE)
            .iter()
            .filter_map(|v| v.to_str().ok())
            .flat_map(|s| s.split(';'))
            .map(|s| s.trim().to_string())
            .collect()
    }

    // 提取公共的 HTTP 头部生成逻辑
    fn build_common_headers(&self, is_request: bool) -> String {
        let realistic_headers = generate_realistic_headers(is_request);
        let mut headers = String::new();

        // 添加基础头部
        headers.push_str(&format!(
            "Date: {}\r\n",
            chrono::Utc::now().format("%a, %d %b %Y %H:%M:%S GMT")
        ));

        // 添加真实的头部
        for (name, value) in realistic_headers.iter() {
            if let Ok(value) = value.to_str() {
                headers.push_str(&format!("{}: {}\r\n", name.as_str(), value));
            }
        }

        headers
    }

    // 提取 Cookie 生成逻辑
    fn build_cookie_header(&self, packet_info: &PacketInfo, is_request: bool) -> Result<String> {
        let cookie_name = HTTP_CONSTANTS.cookie_names
            [rand::thread_rng().gen_range(0..HTTP_CONSTANTS.cookie_names.len())];
        let cookie_value = packet_info.to_cookie()?;

        // 生成真实的 cookie 字符串
        let mut cookies = Vec::new();

        // 添加包含数据的主 cookie
        cookies.push(format!("{}={}", cookie_name, cookie_value));

        // 添加会话 ID
        cookies.push(format!("sid={}", uuid::Uuid::new_v4()));

        // 随机添加一些常见的 cookie
        if rand::random::<bool>() {
            cookies.push(format!(
                "_ga=GA1.2.{}.{}",
                rand::thread_rng().gen::<u32>(),
                rand::thread_rng().gen::<u32>()
            ));
        }
        if rand::random::<bool>() {
            cookies.push(format!("_gid=GA1.2.{}", rand::thread_rng().gen::<u32>()));
        }
        if rand::random::<bool>() {
            cookies.push("theme=light".to_string());
        }

        let cookie_str = cookies.join("; ");

        Ok(if is_request {
            format!("Cookie: {}\r\n", cookie_str)
        } else {
            format!("Set-Cookie: {}\r\n", cookie_str)
        })
    }

    // 提取 Accept 头部生成逻辑
    fn get_accept_header(&self, path: &str) -> &'static str {
        match path {
            p if p.ends_with(".css") => "text/css,*/*;q=0.1",
            p if p.ends_with(".js") => "application/javascript,*/*;q=0.1",
            p if p.ends_with(".png") => "image/png,image/*;q=0.8,*/*;q=0.5",
            p if p.starts_with("/api/") => "application/json",
            _ => "*/*",
        }
    }

    // 获取随机状态码
    fn get_random_status_code(&self) -> u16 {
        let rand_val = rand::random::<f32>();
        let mut acc = 0.0;
        for &(code, prob) in HTTP_CONSTANTS.status_codes {
            acc += prob;
            if rand_val < acc {
                return code;
            }
        }
        200 // 默认返回 200
    }

    async fn build_http_request(
        &self,
        data: &[u8],
        packet_info: &PacketInfo,
        mime_type: &str,
    ) -> Result<Vec<u8>> {
        let use_get = mime_type.contains("text/plain") || mime_type.contains("application/json");
        let method = if use_get { "GET" } else { "POST" };
        let paths = if use_get {
            HTTP_CONSTANTS.get_paths
        } else {
            HTTP_CONSTANTS.post_paths
        };
        let path = paths[rand::thread_rng().gen_range(0..paths.len())];

        let mut headers = String::new();
        // 确保请求行是第一行
        headers.push_str(&format!("{} {} HTTP/1.1\r\n", method, path));
        // 然后添加其他头部
        headers.push_str(&self.build_common_headers(true));
        headers.push_str(&format!("Accept: {}\r\n", self.get_accept_header(path)));
        headers.push_str(&self.build_cookie_header(packet_info, true)?);

        if method == "GET" {
            headers.push_str(&format!("X-Data: {}\r\n", BASE64.encode(data)));
            headers.push_str("\r\n"); // 确保 GET 请求也有空行
        } else {
            let encoded = stego::encode_mime(data, mime_type).await?;
            headers.push_str(&format!("Content-Type: {}\r\n", mime_type));
            headers.push_str(&format!("Content-Length: {}\r\n", encoded.len()));
            headers.push_str("\r\n");
            headers.push_str(&String::from_utf8_lossy(&encoded));
        }

        Ok(headers.into_bytes())
    }

    async fn build_http_response(
        &self,
        data: &[u8],
        packet_info: &PacketInfo,
        mime_type: &str,
        _status_code: u16,
    ) -> Result<Vec<u8>> {
        let encoded = stego::encode_mime(data, mime_type).await?;

        let mut headers = String::new();
        // 确保响应行是第一行
        headers.push_str(&format!(
            "HTTP/1.1 {} OK\r\n",
            self.get_random_status_code()
        ));
        // 然后添加其他头部
        headers.push_str(&self.build_common_headers(false));
        headers.push_str(&format!("Content-Type: {}\r\n", mime_type));
        headers.push_str(&format!("Content-Length: {}\r\n", encoded.len()));
        headers.push_str(&self.build_cookie_header(packet_info, false)?);
        headers.push_str("\r\n");

        let mut response = headers.into_bytes();
        response.extend_from_slice(&encoded);
        Ok(response)
    }

    async fn decode_single_packet(&self, packet: &[u8], packet_index: usize) -> Result<Vec<u8>> {
        let content = String::from_utf8_lossy(packet);
        let (header, body) = content.split_once("\r\n\r\n").ok_or_else(|| {
            RainbowError::InvalidData(HTTP_CONSTANTS.error_details[3].1.to_string())
        })?;

        // 获取请求方法
        let first_line = header
            .lines()
            .next()
            .ok_or_else(|| RainbowError::InvalidData("Cannot get first line".to_string()))?;

        // 处理 GET 请求中的 X-Data header
        if first_line.starts_with("GET") {
            for line in header.lines() {
                if line.to_lowercase().starts_with("x-data:") {
                    let encoded_data =
                        line.split_once(':').map(|(_, v)| v.trim()).ok_or_else(|| {
                            RainbowError::InvalidData("Invalid X-Data header".to_string())
                        })?;
                    return Ok(BASE64.decode(encoded_data).map_err(|_| {
                        RainbowError::InvalidData(HTTP_CONSTANTS.error_details[2].1.to_string())
                    })?);
                }
            }
            return Err(RainbowError::InvalidData(
                "Missing X-Data header in GET request".to_string(),
            ));
        }

        // 处理 POST 请求
        // 获取 MIME 类型
        let mime_type = header
            .lines()
            .find(|line| line.to_lowercase().starts_with("content-type:"))
            .and_then(|line| line.split_once(':'))
            .map(|(_, value)| value.trim())
            .ok_or_else(|| {
                RainbowError::InvalidData(HTTP_CONSTANTS.error_details[0].1.to_string())
            })?;

        debug!(
            "Processing packet {}: MIME type: {}, Content length: {}",
            packet_index,
            mime_type,
            body.len()
        );

        // 解码数据
        let decoded = stego::decode_mime(body.as_bytes(), mime_type).await?;
        debug!("Successfully decoded content: length={}", decoded.len());

        Ok(decoded)
    }

    // 添加验证数据包长度的方法
    fn verify_length(&self, packet: &[u8], expected_length: usize) -> Result<()> {
        let content = String::from_utf8_lossy(packet);
        if let Some((header, _)) = content.split_once("\r\n\r\n") {
            // 获取请求方法
            let first_line = header
                .lines()
                .next()
                .ok_or_else(|| RainbowError::InvalidData("Cannot get first line".to_string()))?;

            // 对于 GET 请求，验证 X-Data 的长度
            if first_line.starts_with("GET") {
                for line in header.lines() {
                    if line.to_lowercase().starts_with("x-data:") {
                        if let Some((_, value)) = line.split_once(':') {
                            let decoded = BASE64.decode(value.trim())?;
                            if decoded.len() == expected_length {
                                return Ok(());
                            }
                        }
                    }
                }
            } else {
                // 对于 POST 请求，验证 Content-Length
                for line in header.lines() {
                    if line.to_lowercase().starts_with("content-length:") {
                        if let Some((_, value)) = line.split_once(':') {
                            if let Ok(length) = value.trim().parse::<usize>() {
                                if length > 0 {
                                    return Ok(());
                                }
                            }
                        }
                    }
                }
            }
        }
        Err(RainbowError::InvalidData(
            "Content length mismatch".to_string(),
        ))
    }
}

#[async_trait]
impl NetworkSteganographyProcessor for Rainbow {
    async fn encode_write(
        &self,
        data: &[u8],
        is_client: bool,
        mime_type: Option<String>,
    ) -> Result<EncodeResult> {
        debug!("Encoding {} bytes of data", data.len());

        let chunks: Vec<_> = data.chunks(CHUNK_SIZE).collect();
        let total_chunks = chunks.len();

        let mut packets = Vec::new();
        let mut expected_lengths = Vec::new();

        for (i, chunk) in chunks.iter().enumerate() {
            let packet_info = PacketInfo::new(i, total_chunks, chunk.len());
            let mime = mime_type.clone().unwrap_or_else(get_random_mime_type);

            // 生成数据包
            let packet = if is_client {
                self.build_http_request(chunk, &packet_info, &mime).await?
            } else {
                self.build_http_response(chunk, &packet_info, &mime, 200)
                    .await?
            };

            // 生成预期的返回包长度
            let expected_length = if is_client {
                // 如果我们是客户端，对方是服务器，预期返回 HTTP 响应
                // 通常响应大小在 200-8000 字节之间
                rand::thread_rng().gen_range(200..8000)
            } else {
                // 如果我们是服务器，对方是客户端，预期返回 HTTP 请求
                // 通常请求大小在 100-2000 字节之间
                rand::thread_rng().gen_range(100..2000)
            };

            let pl = packet.len();

            packets.push(packet);
            expected_lengths.push(expected_length);

            debug!(
                "Generated packet {}/{}: {} bytes, expecting response of {} bytes",
                i + 1,
                total_chunks,
                pl,
                expected_length
            );
        }

        info!(
            "Generated {} packets for {} bytes of data",
            packets.len(),
            data.len()
        );

        Ok(EncodeResult {
            encoded_packets: packets,
            expected_return_packet_lengths: expected_lengths,
        })
    }

    async fn decrypt_single_read(
        &self,
        data: Vec<u8>,
        packet_index: usize,
        is_client: bool,
    ) -> Result<DecodeResult> {
        debug!("Decoding packet of {} bytes", data.len());

        // 验证数据包
        validate_http_packet(&data)?;

        // 解码数据包
        let decoded = self.decode_single_packet(&data, packet_index).await?;

        // 解析 HTTP 头以获取包信息
        let content = String::from_utf8_lossy(&data);
        let mut total_packets = None;
        let mut expected_length = 0;

        // 检查是否为响应
        let is_response = content.starts_with("HTTP/1.1");

        // 验证请求/响应类型与 is_client 是否匹配
        if is_client {
            if is_response {
                return Err(RainbowError::InvalidData(
                    "Client should not receive responses".to_string(),
                ));
            }
        } else {
            if !is_response {
                return Err(RainbowError::InvalidData(
                    "Server should not receive requests".to_string(),
                ));
            }
        }

        // 从 Cookie 中获取包信息
        let mut headers = HeaderMap::new();
        let header_part = content.split("\r\n\r\n").next().unwrap_or("");

        for line in header_part.lines() {
            if line.to_lowercase().starts_with("cookie:") {
                if let Ok(value) = HeaderValue::from_str(&line[7..].trim()) {
                    headers.append(COOKIE, value);
                }
            }
        }

        // 使用 parse_cookies 解析所有 cookie
        for cookie in Rainbow::parse_cookies(&headers) {
            if let Some((name, value)) = cookie.split_once('=') {
                if HTTP_CONSTANTS.cookie_names.contains(&name.trim()) {
                    if let Ok(info) = PacketInfo::from_cookie(value.trim()) {
                        total_packets = Some(info.total);
                        expected_length = info.length;

                        // 验证数据包长度
                        self.verify_length(&data, expected_length)?;
                        break;
                    }
                }
            }
        }

        let total = total_packets.ok_or_else(|| {
            RainbowError::InvalidData("Could not find valid packet info in cookies".to_string())
        })?;

        let is_read_end = packet_index + 1 >= total;

        info!("Successfully decoded {} bytes from packet", decoded.len());
        Ok(DecodeResult {
            data: decoded,
            expected_return_length: expected_length,
            is_read_end,
        })
    }
}

/// 生成指定长度的 HTTP 请求或响应包
///
/// # Arguments
/// * `target_length` - 目标数据包长度
/// * `is_request` - 是否为请求包（true 为请求，false 为响应）
///
/// # Returns
/// 返回指定长度的 HTTP 数据包
pub async fn generate_stego_packet_with_length(
    target_length: usize,
    is_request: bool,
) -> Result<Vec<u8>> {
    // 提取基础头部生成到单独的函数
    fn generate_base_headers(is_request: bool, is_small_packet: bool) -> (String, &'static str) {
        let mut headers = String::new();
        let path = if is_request {
            let method = if is_small_packet { "GET" } else { "GET" };
            let paths = HTTP_CONSTANTS.get_paths;
            let path = if is_small_packet {
                paths.iter().min_by_key(|p| p.len()).unwrap_or(&"/")
            } else {
                paths[rand::thread_rng().gen_range(0..paths.len())]
            };
            headers.push_str(&format!("{} {} HTTP/1.1\r\n", method, path));
            path
        } else {
            let rb = Rainbow::new();
            headers.push_str(&format!("HTTP/1.1 {} OK\r\n", rb.get_random_status_code()));
            ""
        };
        (headers, path)
    }

    let packet_info = PacketInfo::new(0, 1, target_length);
    let is_small_packet = target_length < 1000;

    // 生成基础头部
    let (mut headers, path) = generate_base_headers(is_request, is_small_packet);

    // 选择合适的 MIME 类型
    let mime_type = if is_small_packet {
        "application/json".to_string()
    } else {
        get_random_mime_type()
    };

    // 添加基础头部
    if is_small_packet {
        headers.push_str("Host: localhost\r\n");
        headers.push_str("Connection: close\r\n");
    } else {
        headers.push_str(&format!(
            "Date: {}\r\n",
            chrono::Utc::now().format("%a, %d %b %Y %H:%M:%S GMT")
        ));

        // 添加真实头部
        let realistic_headers = generate_realistic_headers(is_request);
        for (name, value) in realistic_headers {
            if let Some(header_name) = name {
                if let Ok(value_str) = value.to_str() {
                    headers.push_str(&format!("{}: {}\r\n", header_name, value_str));
                }
            }
        }
    }

    // 添加 Cookie 头部
    headers.push_str(&generate_cookie_header(&packet_info, is_request)?);
    headers.push_str(&format!("Content-Type: {}\r\n", mime_type));

    // 预留 Content-Length 占位符
    headers.push_str("Content-Length: 0000000000\r\n\r\n");

    // 优化二分查找逻辑
    let (mut packet, padding_len) =
        find_optimal_packet_size(headers, target_length, &mime_type).await?;

    // 添加填充（如果需要）
    if padding_len > 0 {
        add_padding_to_packet(&mut packet, padding_len)?;
    }

    Ok(packet)
}

// 提取二分查找逻辑到单独的函数
async fn find_optimal_packet_size(
    base_headers: String,
    target_length: usize,
    mime_type: &str,
) -> Result<(Vec<u8>, usize)> {
    let base_header_length = base_headers.len();
    let min_header_length = base_header_length - "0000000000\r\n\r\n".len() + "0\r\n\r\n".len();

    if target_length < min_header_length {
        return Err(RainbowError::InvalidData(format!(
            "Target length {} is too small for headers (min {})",
            target_length, min_header_length
        )));
    }

    let mut left = 1;
    let mut right = target_length - min_header_length;
    let mut best_result = None;

    while left <= right {
        let mid = (left + right) / 2;
        let random_data: Vec<u8> = (0..mid).map(|_| rand::random()).collect();

        let encoded = stego::encode_mime(&random_data, mime_type).await?;
        let total_len = calculate_total_length(&base_headers, &encoded)?;

        match total_len.cmp(&target_length) {
            std::cmp::Ordering::Equal => {
                return Ok((build_final_packet(&base_headers, &encoded)?, 0));
            }
            std::cmp::Ordering::Less => {
                best_result = Some((encoded, target_length - total_len));
                left = mid + 1;
            }
            std::cmp::Ordering::Greater => {
                right = mid - 1;
            }
        }
    }

    best_result.ok_or_else(|| {
        RainbowError::InvalidData(format!(
            "Could not generate packet of length {}",
            target_length
        ))
    })
}

// 辅助函数
fn calculate_total_length(headers: &str, encoded: &[u8]) -> Result<usize> {
    let content_length_str = encoded.len().to_string();
    let header_length =
        headers.len() - "0000000000\r\n\r\n".len() + content_length_str.len() + "\r\n\r\n".len();
    Ok(header_length + encoded.len())
}

fn build_final_packet(headers: &str, encoded: &[u8]) -> Result<Vec<u8>> {
    let mut packet = headers
        .replace("0000000000\r\n\r\n", &format!("{}\r\n\r\n", encoded.len()))
        .into_bytes();
    packet.extend_from_slice(encoded);
    Ok(packet)
}

fn generate_cookie_header(packet_info: &PacketInfo, is_request: bool) -> Result<String> {
    let cookie_name = HTTP_CONSTANTS.cookie_names
        [rand::thread_rng().gen_range(0..HTTP_CONSTANTS.cookie_names.len())];
    let cookie_value = packet_info.to_cookie()?;

    let mut cookies = vec![
        format!("{}={}", cookie_name, cookie_value),
        format!("sid={}", uuid::Uuid::new_v4()),
    ];

    // 添加随机常见 cookie
    if rand::random::<bool>() {
        cookies.push(format!(
            "_ga=GA1.2.{}.{}",
            rand::thread_rng().gen::<u32>(),
            rand::thread_rng().gen::<u32>()
        ));
    }

    let cookie_str = cookies.join("; ");
    Ok(if is_request {
        format!("Cookie: {}\r\n", cookie_str)
    } else {
        format!("Set-Cookie: {}\r\n", cookie_str)
    })
}

fn add_padding_to_packet(packet: &mut Vec<u8>, padding_len: usize) -> Result<()> {
    const PADDING_HEADER: &str = "X-Padding: ";
    let padding = "A".repeat(padding_len);

    if let Some(pos) = String::from_utf8_lossy(packet).find("\r\n") {
        let mut new_packet = packet[..pos].to_vec();
        new_packet.extend_from_slice(b"\r\n");
        new_packet.extend_from_slice(PADDING_HEADER.as_bytes());
        new_packet.extend_from_slice(padding.as_bytes());
        new_packet.extend_from_slice(b"\r\n");
        new_packet.extend_from_slice(&packet[pos + 2..]);
        *packet = new_packet;
        Ok(())
    } else {
        Err(RainbowError::InvalidData(
            "Invalid packet format".to_string(),
        ))
    }
}

#[cfg(test)]
mod tests {
    use crate::EncodeResult;

    use super::*;

    fn init() {
        let _ = tracing_subscriber::fmt()
            .with_test_writer()
            .with_max_level(tracing::Level::DEBUG)
            .try_init();
    }

    #[tokio::test]
    async fn test_generate_packet_with_small_length() {
        init();

        // 测试请求生成 - 使用更大的初始大小
        let target_length = 500;
        let request = generate_stego_packet_with_length(target_length, true)
            .await
            .unwrap();
        assert_eq!(request.len(), target_length);

        let request_str = String::from_utf8_lossy(&request);
        assert!(request_str.starts_with("GET ") || request_str.starts_with("POST "));

        debug!("500 ok");
    }

    #[tokio::test]
    async fn test_generate_packet_with_length() {
        init();

        // 测试请求生成 - 使用更大的初始大小
        let target_length = 2000;
        let request = generate_stego_packet_with_length(target_length, true)
            .await
            .unwrap();
        assert_eq!(request.len(), target_length);

        let request_str = String::from_utf8_lossy(&request);
        assert!(request_str.starts_with("GET ") || request_str.starts_with("POST "));

        debug!("2000 ok");

        // 测试响应生成 - 使用更大的大小
        let target_length = 3000;
        let response = generate_stego_packet_with_length(target_length, false)
            .await
            .unwrap();
        assert_eq!(response.len(), target_length);
        assert!(String::from_utf8_lossy(&response).starts_with("HTTP/1.1"));
    }

    #[tokio::test]
    async fn test_encode_write_basic() {
        init();
        let rainbow = Rainbow::new();
        let test_data = b"Hello, World!";
        let EncodeResult {
            encoded_packets: packets,
            expected_return_packet_lengths: lengths,
        } = rainbow.encode_write(test_data, true, None).await.unwrap();

        assert!(!packets.is_empty());
        assert_eq!(packets.len(), lengths.len());
        assert!(lengths[0] >= 200 && lengths[0] <= 8000);
    }

    #[tokio::test]
    async fn test_encode_write_large_data() {
        init();
        let rainbow = Rainbow::new();
        let test_data = vec![0u8; CHUNK_SIZE * 2 + 100]; // 创建超过两个块的数据
        let EncodeResult {
            encoded_packets: packets,
            expected_return_packet_lengths: lengths,
        } = rainbow.encode_write(&test_data, true, None).await.unwrap();

        assert_eq!(packets.len(), 3);
        assert_eq!(lengths.len(), 3);
        for length in lengths {
            assert!(length >= 200 && length <= 8000);
        }
    }

    #[tokio::test]
    async fn test_expected_lengths_ranges() {
        init();
        let rainbow = Rainbow::new();
        let test_data = b"Test Data";

        // 测试客户端发送（期待服务器响应）
        let EncodeResult {
            encoded_packets: _,
            expected_return_packet_lengths: client_lengths,
        } = rainbow.encode_write(test_data, true, None).await.unwrap();
        assert!(client_lengths[0] >= 200 && client_lengths[0] <= 8000);

        // 测试服务器发送（期待客户端请求）
        let EncodeResult {
            encoded_packets: _,
            expected_return_packet_lengths: server_lengths,
        } = rainbow.encode_write(test_data, false, None).await.unwrap();
        assert!(server_lengths[0] >= 100 && server_lengths[0] <= 2000);
    }

    #[tokio::test]
    async fn test_request_response_format() {
        init();
        let rainbow = Rainbow::new();
        let test_data = b"Test Data";

        // 测试客户端请求
        let EncodeResult {
            encoded_packets: request_packets,
            expected_return_packet_lengths: _,
        } = rainbow.encode_write(test_data, true, None).await.unwrap();
        let request = String::from_utf8_lossy(&request_packets[0]);
        assert!(request.starts_with("GET ") || request.starts_with("POST "));

        // 测试服务器响应
        let EncodeResult {
            encoded_packets: response_packets,
            expected_return_packet_lengths: _,
        } = rainbow.encode_write(test_data, false, None).await.unwrap();
        let response = String::from_utf8_lossy(&response_packets[0]);
        assert!(response.starts_with("HTTP/1.1"));
    }

    #[tokio::test]
    async fn test_mime_type_handling() {
        init();
        let rainbow = Rainbow::new();
        let test_data = b"Test Data";
        let mime_type = Some("text/plain".to_string());

        let EncodeResult {
            encoded_packets: packets,
            expected_return_packet_lengths: _,
        } = rainbow
            .encode_write(test_data, true, mime_type)
            .await
            .unwrap();
        let packet = String::from_utf8_lossy(&packets[0]);

        // 对于 text/plain，应该使用 GET 请求
        assert!(packet.starts_with("GET "));
        assert!(packet.contains("X-Data:"));
    }

    #[tokio::test]
    async fn test_packet_info_cookie() {
        init();
        let info = PacketInfo::new(0, 1, 10);
        let cookie = info.to_cookie().unwrap();
        let decoded = PacketInfo::from_cookie(&cookie).unwrap();

        assert_eq!(info.index, decoded.index);
        assert_eq!(info.total, decoded.total);
        assert_eq!(info.length, decoded.length);
        assert_eq!(info.version, decoded.version);
    }

    #[tokio::test]
    async fn test_full_encode_decode_cycle() {
        init();
        let rainbow = Rainbow::new();
        let test_data = b"Hello, World!";

        // 编码：模拟客户端发送请求，使用 application/octet-stream 强制 POST 请求
        let EncodeResult {
            encoded_packets: packets,
            expected_return_packet_lengths: _lengths,
        } = rainbow
            .encode_write(
                test_data,
                true,
                Some("application/octet-stream".to_string()),
            )
            .await
            .unwrap();

        // 解码：模拟服务器接收请求
        let DecodeResult {
            data: decoded,
            expected_return_length: length,
            is_read_end: is_end,
        } = rainbow
            .decrypt_single_read(packets[0].clone(), 0, true)
            .await
            .unwrap();

        assert_eq!(&decoded, test_data);
        assert_eq!(length, test_data.len());
        assert!(is_end);
    }

    #[tokio::test]
    async fn test_invalid_packet_validation() {
        init();
        let rainbow = Rainbow::new();
        let invalid_packet = b"Invalid HTTP packet".to_vec();

        let result = rainbow.decrypt_single_read(invalid_packet, 0, false).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_cookie_parsing() {
        init();
        let mut headers = HeaderMap::new();
        headers.insert(
            COOKIE,
            HeaderValue::from_str("visitor=test; _ga=123; JSESSIONID=abc").unwrap(),
        );

        let cookies = Rainbow::parse_cookies(&headers);
        assert_eq!(cookies.len(), 3);
        assert!(cookies.contains(&"visitor=test".to_string()));
        assert!(cookies.contains(&"_ga=123".to_string()));
        assert!(cookies.contains(&"JSESSIONID=abc".to_string()));
    }
}

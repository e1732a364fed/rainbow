use async_trait::async_trait;
use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use chrono::Utc;
use rand::Rng;
use reqwest::header::{HeaderMap, HeaderValue, COOKIE};
use serde::{Deserialize, Serialize};
use tracing::{debug, info};

use crate::{
    stego::{self, get_random_mime_type},
    Name, RainbowError, Result, SteganographyProcessor,
};

const CHUNK_SIZE: usize = 1024;

// 将常量组织到一个结构中
struct HttpConstants {
    cookie_names: &'static [&'static str],
    post_paths: &'static [&'static str],
    get_paths: &'static [&'static str],
    error_details: &'static [(&'static str, &'static str)], // (状态码, 出现概率)
    status_codes: &'static [(u16, f32)],                    // (状态码, 出现概率)
}

const HTTP_CONSTANTS: HttpConstants = HttpConstants {
    cookie_names: &[
        "sessionId",
        "visitor",
        "track",
        "_ga",
        "_gid",
        "JSESSIONID",
        "cf_id",
    ],
    post_paths: &[
        "/api/v1/data",
        "/api/v1/upload",
        "/api/v2/submit",
        "/upload",
        "/submit",
        "/process",
    ],
    get_paths: &[
        "/",
        "/index.html",
        "/assets/main.css",
        "/js/app.js",
        "/images/logo.png",
        "/blog/latest",
        "/docs/guide",
    ],
    error_details: &[
        ("MIME_TYPE_MISSING", "Missing Content-Type header"),
        ("CONTENT_MISSING", "Missing content body"),
        ("BASE64_DECODE_FAILED", "Failed to decode Base64 data"),
        ("INVALID_PACKET_FORMAT", "Invalid packet format"),
        ("UNSUPPORTED_MIME_TYPE", "Unsupported MIME type"),
    ],
    status_codes: &[
        (200, 0.9), // 90% 概率
        (201, 0.025),
        (202, 0.025),
        (204, 0.025),
        (206, 0.025),
    ],
};

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

#[derive(Debug, Clone)]
pub struct Rainbow {
    name: &'static str,
}

impl Rainbow {
    pub fn new() -> Self {
        Self { name: "rainbow" }
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
        let realistic_headers = self.generate_realistic_headers(is_request);
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

    fn validate_http_packet(&self, packet: &[u8]) -> Result<()> {
        if packet.len() < 16 {
            return Err(RainbowError::InvalidData("Packet too short".to_string()));
        }

        let content = String::from_utf8_lossy(packet);
        let first_line = content.lines().next().ok_or_else(|| {
            RainbowError::InvalidData("Cannot get first line of packet".to_string())
        })?;

        // 更宽松的 HTTP 格式验证
        if first_line.starts_with("HTTP/") && first_line.contains(" ") {
            debug!("Valid HTTP response format");
            return Ok(());
        }

        if first_line.split_whitespace().count() == 3
            && first_line.contains("HTTP/")
            && (first_line.starts_with("GET ") || first_line.starts_with("POST "))
        {
            debug!("Valid HTTP request format");
            return Ok(());
        }

        Err(RainbowError::InvalidData("Invalid HTTP format".to_string()))
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

    fn generate_realistic_headers(&self, is_request: bool) -> HeaderMap {
        let mut headers = HeaderMap::new();

        if is_request {
            headers.insert(
                "User-Agent",
                HeaderValue::from_static(
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                ),
            );
            headers.insert(
                "Accept-Language",
                HeaderValue::from_static("en-US,en;q=0.9"),
            );
            headers.insert(
                "Accept-Encoding",
                HeaderValue::from_static("gzip, deflate, br"),
            );

            // 随机添加一些可选头部
            if rand::random::<bool>() {
                headers.insert("DNT", HeaderValue::from_static("1"));
            }
            if rand::random::<bool>() {
                headers.insert("Cache-Control", HeaderValue::from_static("max-age=0"));
            }
        } else {
            headers.insert("Server", HeaderValue::from_static("nginx/1.18.0"));
            headers.insert("X-Frame-Options", HeaderValue::from_static("SAMEORIGIN"));
            headers.insert(
                "X-Content-Type-Options",
                HeaderValue::from_static("nosniff"),
            );

            // 随机添加一些安全相关的头部
            if rand::random::<bool>() {
                headers.insert(
                    "Strict-Transport-Security",
                    HeaderValue::from_static("max-age=31536000; includeSubDomains"),
                );
            }
            if rand::random::<bool>() {
                headers.insert(
                    "Content-Security-Policy",
                    HeaderValue::from_static("default-src 'self'"),
                );
            }
        }

        headers
    }
}

impl Name for Rainbow {
    fn name(&self) -> &'static str {
        self.name
    }
}

#[async_trait]
impl SteganographyProcessor for Rainbow {
    async fn encode_write(
        &self,
        data: &[u8],
        is_client: bool,
        mime_type: Option<String>,
    ) -> Result<(Vec<Vec<u8>>, Vec<usize>)> {
        debug!("Encoding {} bytes of data", data.len());

        // 将数据分块
        let chunks: Vec<_> = data.chunks(CHUNK_SIZE).collect();
        let total_chunks = chunks.len();

        let mut packets = Vec::new();
        let mut expected_lengths = Vec::new();

        // 为每个数据块生成 HTTP 包
        for (i, chunk) in chunks.iter().enumerate() {
            let packet_info = PacketInfo::new(i, total_chunks, chunk.len());
            let mime = mime_type.clone().unwrap_or_else(get_random_mime_type);

            // 根据 is_client 决定生成请求还是响应
            let packet = if is_client {
                self.build_http_request(chunk, &packet_info, &mime).await?
            } else {
                // 对于响应，随机生成一个合理的状态码
                let status_code = if rand::random::<f32>() < 0.9 {
                    200 // 90% 的概率返回 200
                } else {
                    // 10% 的概率返回其他状态码
                    let other_codes = [201, 202, 204, 206];
                    other_codes[rand::thread_rng().gen_range(0..other_codes.len())]
                };
                self.build_http_response(chunk, &packet_info, &mime, status_code)
                    .await?
            };
            let pl = packet.len();

            packets.push(packet);
            expected_lengths.push(chunk.len());

            debug!("Generated packet {}/{}: {} bytes", i + 1, total_chunks, pl);
        }

        info!(
            "Generated {} packets for {} bytes of data",
            packets.len(),
            data.len()
        );

        Ok((packets, expected_lengths))
    }

    async fn decrypt_single_read(
        &self,
        data: Vec<u8>,
        packet_index: usize,
        is_client: bool,
    ) -> Result<(Vec<u8>, usize, bool)> {
        debug!("Decoding packet of {} bytes", data.len());

        // 验证数据包
        self.validate_http_packet(&data)?;

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
        Ok((decoded, expected_length, is_read_end))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_encode_write_basic() {
        let rainbow = Rainbow::new();
        let test_data = b"Hello, World!";
        let (packets, lengths) = rainbow.encode_write(test_data, true, None).await.unwrap();

        assert!(!packets.is_empty());
        assert_eq!(packets.len(), lengths.len());
        assert_eq!(lengths[0], test_data.len());
    }

    #[tokio::test]
    async fn test_encode_write_large_data() {
        let rainbow = Rainbow::new();
        let test_data = vec![0u8; CHUNK_SIZE * 2 + 100]; // 创建超过两个块的数据
        let (packets, lengths) = rainbow.encode_write(&test_data, true, None).await.unwrap();

        assert_eq!(packets.len(), 3);
        assert_eq!(lengths.len(), 3);
        assert_eq!(lengths[0], CHUNK_SIZE);
        assert_eq!(lengths[1], CHUNK_SIZE);
        assert_eq!(lengths[2], 100);
    }

    #[tokio::test]
    async fn test_request_response_format() {
        let rainbow = Rainbow::new();
        let test_data = b"Test Data";

        // 测试客户端请求
        let (request_packets, _) = rainbow.encode_write(test_data, true, None).await.unwrap();
        let request = String::from_utf8_lossy(&request_packets[0]);
        assert!(request.starts_with("GET ") || request.starts_with("POST "));

        // 测试服务器响应
        let (response_packets, _) = rainbow.encode_write(test_data, false, None).await.unwrap();
        let response = String::from_utf8_lossy(&response_packets[0]);
        assert!(response.starts_with("HTTP/1.1"));
    }

    #[tokio::test]
    async fn test_mime_type_handling() {
        let rainbow = Rainbow::new();
        let test_data = b"Test Data";
        let mime_type = Some("text/plain".to_string());

        let (packets, _) = rainbow
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
        let rainbow = Rainbow::new();
        let test_data = b"Hello, World!";

        // 编码：模拟客户端发送请求，使用 application/octet-stream 强制 POST 请求
        let (packets, _) = rainbow
            .encode_write(
                test_data,
                true,
                Some("application/octet-stream".to_string()),
            )
            .await
            .unwrap();

        // 解码：模拟服务器接收请求
        let (decoded, length, is_end) = rainbow
            .decrypt_single_read(packets[0].clone(), 0, true)
            .await
            .unwrap();

        assert_eq!(&decoded, test_data);
        assert_eq!(length, test_data.len());
        assert!(is_end);
    }

    #[tokio::test]
    async fn test_invalid_packet_validation() {
        let rainbow = Rainbow::new();
        let invalid_packet = b"Invalid HTTP packet".to_vec();

        let result = rainbow.decrypt_single_read(invalid_packet, 0, false).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_cookie_parsing() {
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

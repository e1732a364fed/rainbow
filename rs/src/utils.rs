use rand::{distributions::Alphanumeric, Rng};
use reqwest::header::{HeaderMap, HeaderName, HeaderValue};

/// 生成指定长度的随机字符串
pub fn random_string(length: usize) -> String {
    rand::thread_rng()
        .sample_iter(&Alphanumeric)
        .take(length)
        .map(char::from)
        .collect()
}

/// 生成真实的 HTTP 头部
pub fn generate_realistic_headers() -> HeaderMap {
    let mut headers = HeaderMap::new();

    // 常见的浏览器 User-Agent
    let user_agents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0",
    ];

    headers.insert(
        "user-agent",
        HeaderValue::from_str(user_agents[rand::thread_rng().gen_range(0..user_agents.len())])
            .unwrap(),
    );

    // 添加其他常见头部
    headers.insert(
        "accept-language",
        HeaderValue::from_static("en-US,en;q=0.9"),
    );
    headers.insert(
        "accept-encoding",
        HeaderValue::from_static("gzip, deflate, br"),
    );
    headers.insert("connection", HeaderValue::from_static("keep-alive"));

    headers
}

/// 生成随机的 API 路径
pub fn generate_random_api_path() -> String {
    let api_paths = [
        "/api/v1/data",
        "/api/v1/upload",
        "/api/v2/submit",
        "/upload",
        "/submit",
        "/process",
    ];

    api_paths[rand::thread_rng().gen_range(0..api_paths.len())].to_string()
}

/// 生成随机的静态资源路径
pub fn generate_random_static_path() -> String {
    let static_paths = [
        "/",
        "/index.html",
        "/assets/main.css",
        "/js/app.js",
        "/images/logo.png",
        "/blog/latest",
        "/docs/guide",
    ];

    static_paths[rand::thread_rng().gen_range(0..static_paths.len())].to_string()
}

/// 检查 HTTP 包的有效性
pub fn validate_http_packet(data: &[u8]) -> bool {
    if let Ok(first_line) =
        std::str::from_utf8(&data[..data.iter().position(|&b| b == b'\n').unwrap_or(data.len())])
    {
        // 检查是否是响应
        if first_line.starts_with("HTTP/") && first_line.contains(" ") {
            return true;
        }

        // 检查是否是请求
        if first_line.split_whitespace().count() == 3 && first_line.contains("HTTP/") {
            return true;
        }
    }

    false
}

/// 从 HTTP 包中提取头部和内容
pub fn extract_http_parts(data: &[u8]) -> Option<(HeaderMap, Vec<u8>)> {
    let data_str = String::from_utf8_lossy(data);
    let mut parts = data_str.split("\r\n\r\n");

    let headers_str = parts.next()?;
    let content = parts.next()?.as_bytes().to_vec();

    let mut headers = HeaderMap::new();
    for line in headers_str.lines().skip(1) {
        // 跳过请求/响应行
        if let Some((name, value)) = line.split_once(':') {
            if let Ok(header_name) = HeaderName::from_bytes(name.trim().as_bytes()) {
                if let Ok(header_value) = HeaderValue::from_str(value.trim()) {
                    headers.insert(header_name, header_value);
                }
            }
        }
    }

    Some((headers, content))
}

use rainbow::rainbow::Rainbow;
use rainbow::SteganographyProcessor;
use tokio::fs;

async fn test_stego(
    rainbow: &Rainbow,
    data: &[u8],
    mime_type: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("\n测试 {} 隐写:", mime_type);
    println!("原始数据: {}", String::from_utf8_lossy(data));

    // 编码数据
    let (packets, lengths) = rainbow
        .encode_write(data, true, Some(mime_type.to_string()))
        .await?;

    println!("\n生成了 {} 个数据包", packets.len());

    println!("packets: {:?}", String::from_utf8_lossy(&packets[0]));

    // 创建输出目录
    fs::create_dir_all(format!(
        "examples/data/output/{}",
        mime_type.split('/').last().unwrap()
    ))
    .await?;

    // 保存并解码每个数据包
    for (i, (packet, length)) in packets.iter().zip(lengths.iter()).enumerate() {
        let file_path = format!(
            "examples/data/output/{}/packet_{}.http",
            mime_type.split('/').last().unwrap(),
            i
        );
        fs::write(&file_path, packet).await?;
        println!("写入包 {} 到 {}, 长度: {}", i, file_path, length);

        // 解码数据包
        let (decoded, expected_length, is_end) =
            rainbow.decrypt_single_read(packet.clone(), i, true).await?;

        println!(
            "解码包 {}: 长度 = {}, 预期长度 = {}, 是否为最后一个包 = {}",
            i,
            decoded.len(),
            expected_length,
            is_end
        );
        println!("解码内容: {}\n", String::from_utf8_lossy(&decoded));
    }

    Ok(())
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 初始化日志
    tracing_subscriber::fmt::init();

    // 创建 Rainbow 实例
    let rainbow = Rainbow::new();

    // 读取测试文件
    let data = fs::read("examples/data/test.txt").await?;

    // 测试所有支持的 MIME 类型
    let mime_types = [
        "text/html",
        "text/css",
        "application/json",
        "application/xml",
    ];

    for mime_type in mime_types {
        test_stego(&rainbow, &data, mime_type).await?;
    }

    Ok(())
}

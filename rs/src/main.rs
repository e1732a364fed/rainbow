use std::path::PathBuf;

use clap::{Parser, Subcommand};
use rainbow::rainbow::Rainbow;
use rainbow::SteganographyProcessor;
use tokio::fs;
use tracing::info;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// 编码数据到 HTTP 包中
    Encode {
        /// 输入文件路径
        #[arg(short, long)]
        input: PathBuf,

        /// 输出目录路径
        #[arg(short, long)]
        output: PathBuf,

        /// 是否作为客户端编码
        #[arg(short, long)]
        client: bool,

        /// MIME 类型
        #[arg(short, long)]
        mime_type: Option<String>,
    },

    /// 解码单个 HTTP 包
    Decode {
        /// 输入文件路径
        #[arg(short, long)]
        input: PathBuf,

        /// 输出文件路径
        #[arg(short, long)]
        output: PathBuf,

        /// 包索引
        #[arg(short, long, default_value = "0")]
        index: usize,

        /// 是否作为客户端解码
        #[arg(short, long)]
        client: bool,
    },
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 初始化日志
    tracing_subscriber::fmt::init();

    let cli = Cli::parse();
    let rainbow = Rainbow::new();

    match cli.command {
        Commands::Encode {
            input,
            output,
            client,
            mime_type,
        } => {
            // 读取输入文件
            let data = fs::read(&input).await?;

            // 编码数据
            let (packets, lengths) = rainbow.encode_write(&data, client, mime_type).await?;

            // 创建输出目录
            fs::create_dir_all(&output).await?;

            // 写入每个包到单独的文件
            for (i, (packet, length)) in packets.iter().zip(lengths.iter()).enumerate() {
                let file_path = output.join(format!("packet_{}.http", i));
                fs::write(&file_path, packet).await?;
                info!("写入包 {} 到 {:?}, 长度: {}", i, file_path, length);
            }
        }

        Commands::Decode {
            input,
            output,
            index,
            client,
        } => {
            // 读取输入文件
            let data = fs::read(&input).await?;

            // 解码数据
            let (decoded, expected_length, is_end) =
                rainbow.decrypt_single_read(data, index, client).await?;

            // 写入解码后的数据
            fs::write(&output, decoded).await?;
            info!(
                "解码包 {} 到 {:?}, 预期长度: {}, 是否为最后一个包: {}",
                index, output, expected_length, is_end
            );
        }
    }

    Ok(())
}

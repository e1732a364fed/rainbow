use async_trait::async_trait;
use dyn_clone::DynClone;
use thiserror::Error;

pub mod rainbow;
pub mod stego;
pub mod utils;

#[derive(Error, Debug)]
pub enum RainbowError {
    #[error("Invalid data: {0}")]
    InvalidData(String),

    #[error("Encode failed: {0}")]
    EncodeFailed(String),

    #[error("Decode failed: {0}")]
    DecodeFailed(String),

    #[error("Length mismatch: {0}")]
    LengthMismatch(String),

    #[error("HTTP error: {0}")]
    HttpError(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("Base64 decode error: {0}")]
    Base64Error(#[from] base64::DecodeError),

    #[error("JSON error: {0}")]
    JsonError(#[from] serde_json::Error),

    #[error("Other: {0}")]
    Other(String),
}

pub type Result<T> = std::result::Result<T, RainbowError>;

pub trait Name {
    fn name(&self) -> &'static str;
}

#[async_trait]
pub trait SteganographyProcessor: Send + Sync + Name + DynClone {
    async fn encode_write(
        &self,
        data: &[u8],
        is_client: bool,
        mime_type: Option<String>,
    ) -> Result<(Vec<Vec<u8>>, Vec<usize>)>;

    //return decoded, expected_return_length, is_read_end
    async fn decrypt_single_read(
        &self,
        data: Vec<u8>,
        packet_index: usize,
        is_client: bool,
    ) -> Result<(Vec<u8>, usize, bool)>;
}
dyn_clone::clone_trait_object!(SteganographyProcessor);

impl From<std::string::FromUtf8Error> for RainbowError {
    fn from(err: std::string::FromUtf8Error) -> Self {
        RainbowError::Other(err.to_string())
    }
}

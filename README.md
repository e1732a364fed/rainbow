# Rainbow

rainbow 是一个网络隐写协议项目，可以用于在网络数据包交换中隐藏数据。

虽然为 网络数据包隐写设计，但是本项目中不含有任何网络数据包交换的代码，而只是提供一对编码和解码的 函数。

rainbow 项目包含两个语言的版本，分别是 lua 版本和 rust 版本。

# Rainbow lua 版本

在 rainbow 目录下

本项目可以在lua5.3正常运行。无法在lua5.1正常运行

## 测试

首先要使用 luarocks 安装 luaunit 库

```bash
luarocks install luaunit
```

(linux 端要安 liblua5.3, 而且可能要用 sudo , 
且 linux 上的 luarocks 最好不要用 apt 安装而是用luarocks 上提供的源码安装命令)


多次测试指定
```bash
lua tests/run_tests.lua 200 -v TestMain.test_different_encoders
```

单次测试指定

```bash
lua tests/run_tests.lua -v TestMain.test_different_encoders
```

测试一个文件多次

```bash
lua tests/run_tests.lua 20 -v TestMain
```

测试一个文件

```bash
lua tests/run_tests.lua -v TestMain
```

测试全部文件（这里不能指定运行次数，只能单次运行）

```bash
lua tests/run_tests.lua
```

# Rainbow rust 版本

在 rs 目录下, 为 国际化项目，全项目使用英文。

trait NetworkSteganographyProcessor 是本项目的核心，定义了 encode_write 和 decrypt_single_read 两个方法。

# 人工智能生成的内容

本项目由 cloude-3.5-sonnet 模型提供支持，由 ruci 项目中的 prompt 生成的代码经人工指导生成、编辑、调试而得

prompt 由

```
You are a cybersecurity expert and network protocol designer specializing in network steganography. 
Your goal is to design a covert HTTP steganography protocol that is undetectable by modern DPI systems while maintaining efficient data transmission.
```
和 ruci 的 `[prompt](https://github.com/e1732a364fed/ruci/tree/tokio/rucimp/src/map/steganography/ai_generated/ai_generate_protocol_prompt.md)` 文件的内容组成

因为本项目包含人工智能生成的内容，故选择使用了 cc0 开源许可

# License

This project is licensed under the CC0 1.0 Universal License.

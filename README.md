# Rainbow


## 运行

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

## 人工智能生成的内容

本项目由 cloude-3.5-sonnet 模型提供支持，由 ruci 项目中的 prompt 生成的代码经人工指导生成、编辑、调试而得

prompt 由

```
You are a cybersecurity expert and network protocol designer specializing in network steganography. 
Your goal is to design a covert HTTP steganography protocol that is undetectable by modern DPI systems while maintaining efficient data transmission.
```
和 ruci 的 `rucimp/src/map/steganography/ai_generated/ai_generate_protocol_prompt.md` 文件的内容组成

因为本项目包含人工智能生成的内容，故选择使用了 cc0 开源许可

# License

This project is licensed under the CC0 1.0 Universal License.

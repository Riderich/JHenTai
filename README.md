# JHenTai Image Translation

> 在 JHenTai 阅读器中直接完成漫画文字检测、日文 OCR、机器翻译、原文擦除和中文嵌字。

[![Windows](https://img.shields.io/badge/Windows-x64-0078D4?logo=windows)](https://github.com/Riderich/JHenTai-Image-Translation/releases)
[![Release](https://img.shields.io/github/v/release/Riderich/JHenTai-Image-Translation)](https://github.com/Riderich/JHenTai-Image-Translation/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/Riderich/JHenTai-Image-Translation/total)](https://github.com/Riderich/JHenTai-Image-Translation/releases)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue)](LICENSE)

[下载 Windows 正式版](https://github.com/Riderich/JHenTai-Image-Translation/releases/latest) · [报告问题](https://github.com/Riderich/JHenTai-Image-Translation/issues/new/choose) · [查看更新记录](https://github.com/Riderich/JHenTai-Image-Translation/releases)

## 项目简介

这是一个基于 [JHenTai](https://github.com/jiangtian616/JHenTai) 开发的漫画图片翻译版本。项目把完整翻译流程接入阅读界面，让用户找到日文漫画后，直接在软件内生成并阅读中文译图。

当前正式支持 **Windows x64**。`v1.1` 开始提供 Android ARM64 独立翻译实验版，不需要连接电脑或运行 Python 服务。

本项目是社区衍生版本，并非 JHenTai 官方版本。使用中遇到的问题请提交到本仓库，不要向原版 JHenTai 报告本项目特有的问题。

## 当前功能

- 在阅读界面翻译当前页
- Windows 阅读界面右键图片即可翻译、重新翻译或切换原图/译图
- 手动设置起始页和结束页，串行翻译指定范围
- 显示范围任务进度，并可在当前页完成后停止
- 在原图与译图之间切换
- 本地缓存已经完成的译图，避免重复消耗时间和 API
- 自定义 OpenAI 兼容 API 地址、API Key 和任意模型名称
- DeepSeek 作为默认预设，也可连接其他云端服务或本机兼容接口
- 可选择是否发送关闭思考参数
- 支持 NLLB 600M / 1.3B 本地翻译，不需要 API Key
- 软件内一键初始化 Windows 翻译环境
- 自动准备 Python、隔离环境、检测/OCR/擦字依赖及默认模型
- 初始化完成后由 JHenTai 自动启动本地翻译服务
- Android 内置日文 OCR、手机端擦字与中文嵌字，仅把识别文字发送给自定义 API

## 下载

请从 [Releases](https://github.com/Riderich/JHenTai-Image-Translation/releases) 下载最新的 Windows 正式版。

当前正式版：

- [JHenTai Image Translation v1.0.0](https://github.com/Riderich/JHenTai-Image-Translation/releases/tag/v1.0.0)

Android v1.1 实验版面向 ARM64 手机（包括 OPPO Find X8）。安装 APK 后进入 **设置 → 漫画翻译**，填写 OpenAI 兼容 API 地址、Key 和模型即可；安卓端不显示 Windows 本地服务设置。

> Android v1.1 使用内置日文 OCR 和轻量矩形擦字排版。复杂气泡、艺术字、拟声词和竖排文字的效果仍需要继续进行真机优化。

下载后必须**完整解压**，不要直接在压缩包中运行程序。目录中的 `app`、`translation_service` 和 `translation_engine` 都是初始化所需内容。

## 首次初始化

1. 运行 `app/jhentai.exe`。
2. 打开 **设置 → 漫画翻译**。
3. 点击 **初始化翻译环境**。
4. 等待软件自动安装独立 Python 环境、图片处理依赖和默认模型。
5. 初始化完成后，状态会变成“翻译服务已就绪”。
6. 选择自定义 API 或 NLLB 本地翻译。使用 API 时填写服务地址、Key 和模型名称，然后保存并测试连接。

初始化预计下载约 **4–7 GB**，建议至少预留 **12 GB** 可用空间。网络速度、PyTorch 依赖和模型下载会显著影响耗时。下载中断后可以点击重试，已经下载或安装的内容会尽量复用。

初始化器会自动检测 NVIDIA 显卡。用户可以选择 CUDA 12.8 加速；驱动或运行时验证失败时会自动回退 CPU 兼容模式。

## 翻译漫画

1. 在 JHenTai 中打开一本漫画并进入阅读界面。
2. 打开顶部菜单，点击翻译图标。
3. 选择 **翻译当前页**，或者选择 **翻译页面范围…**。
4. 等待检测、OCR、所选翻译模型、擦字和中文嵌字完成。
5. 使用菜单中的 **显示原图/显示译图** 检查效果。

Android 用户也可以长按当前漫画图片，在底部菜单中选择 **翻译当前页**、**重新翻译当前页**或切换原图/译图。

范围翻译每次只处理一页，避免同时占用过多内存、显存和 API 请求。已经成功缓存的页面会自动跳过。

## 工作流程

```text
漫画原图
  → 本机文字区域检测
  → 本机日文 OCR
  → 自定义 API 或 NLLB 本地模型翻译识别出的文字
  → 本机擦除原文
  → 本机排版并嵌入中文
  → 缓存并显示完整译图
```

图片处理通过本机 `127.0.0.1` 服务完成。API Key 保存在 JHenTai 的本机配置中，并随翻译请求传给本机服务；所选 API 服务商接收需要翻译的文字。本地 NLLB 模式不会调用翻译 API。请勿把本项目的本地 HTTP 服务暴露到公网，也不要把自己的 Key 写入源码、日志或 Issue。

## 资源消耗

| 阶段 | 主要资源 | 说明 |
|---|---|---|
| 初始化 | 网络、磁盘、CPU | 安装 Python/PyTorch 依赖并下载模型，耗时最长 |
| 文字检测与 OCR | CPU/GPU、内存/显存 | 可用 CUDA 时可启用 GPU；漫画分辨率越高耗时越长 |
| 自定义 API 翻译 | 网络、API 额度 | 支持 OpenAI 兼容接口，思考开关由用户决定 |
| NLLB 本地翻译 | CPU/GPU、内存/显存 | 无 API 成本；CUDA 设备建议使用更大的 1.3B 模型 |
| 擦字与中文嵌字 | CPU、内存 | 在本机生成最终译图 |
| 译图缓存 | 磁盘 | 已翻译页面会保存在 JHenTai 数据目录中 |

## 已知限制

- 当前只发布 Windows x64 一键初始化包
- Android v1.1 当前只提供 ARM64 API 翻译，不含 NLLB 离线翻译模型
- 首次初始化下载量大，部分网络环境可能需要重试
- 不支持 CUDA 的设备会使用 CPU 模式，处理速度较慢
- Clash 系统代理、TUN/虚拟网卡或安全软件可能影响 Python、模型和 API 服务连接
- OCR、气泡检测、擦字与排版仍可能出现错误
- API Key 当前保存在本机应用配置中，尚未接入系统凭据保险库
- Android 内置 OCR 对复杂漫画字体的识别率可能低于桌面漫画专用 OCR

## 问题反馈与参与开发

遇到初始化、连接或翻译问题时，请使用仓库的 [Issue 模板](https://github.com/Riderich/JHenTai-Image-Translation/issues/new/choose)，并附上 Windows 版本、软件版本、CPU/GPU、翻译方式及可公开的错误信息。请先删除 API Key、Cookie、访问令牌和漫画图片中的隐私内容。

如果希望贡献代码，请先阅读 [贡献指南](CONTRIBUTING.md)；安全问题请按照 [安全说明](SECURITY.md) 私下报告。

稳定分支：`main`。功能开发分支：`feature/image-translation`。

本地构建 Windows 版：

```powershell
flutter pub get
flutter build windows --release -t lib/src/main.dart
```

翻译适配层位于 `translation_service/`。对 `manga-image-translator` 的必要兼容改动以补丁形式保存在：

```text
translation_service/manga-image-translator.patch
```

## 上游项目与致谢

本仓库是在以下开源项目基础上进行的社区衍生开发：

- [JHenTai](https://github.com/jiangtian616/JHenTai)：跨平台 E-Hentai/ExHentai 客户端与阅读器界面
- [manga-image-translator](https://github.com/zyddnys/manga-image-translator)：文字检测、OCR、翻译、擦字和嵌字流程
- [DeepSeek](https://www.deepseek.com/)：可选的在线机器翻译模型服务

本项目名称中的 JHenTai 用于说明技术来源和兼容关系，不代表获得原项目官方背书。

## 许可证

本仓库继续遵循 [Apache License 2.0](LICENSE)。上游依赖、模型、字体和第三方服务分别适用其各自的许可证及使用条款。

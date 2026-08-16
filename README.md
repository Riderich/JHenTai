# JHenTai Image Translation

> 在 JHenTai 阅读器中直接完成漫画文字检测、日文 OCR、机器翻译、原文擦除和中文嵌字。

[![Windows](https://img.shields.io/badge/Windows-x64-0078D4?logo=windows)](https://github.com/Riderich/JHenTai-Image-Translation/releases)
[![Release](https://img.shields.io/github/v/release/Riderich/JHenTai-Image-Translation?include_prereleases)](https://github.com/Riderich/JHenTai-Image-Translation/releases)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue)](LICENSE)

## 项目简介

这是一个基于 [JHenTai](https://github.com/jiangtian616/JHenTai) 开发的实验性漫画图片翻译版本。项目把完整翻译流程接入阅读界面，目标是让用户找到日文漫画后，直接在软件内生成并阅读中文译图。

当前重点维护 **Windows x64 测试版**。安卓独立版仍在规划中；现阶段的 Release 不包含安卓翻译功能。

本项目仍处于 Alpha 阶段，并非 JHenTai 官方版本。使用中遇到的问题请提交到本仓库，不要向原版 JHenTai 报告本项目特有的问题。

## 当前功能

- 在阅读界面翻译当前页
- 手动设置起始页和结束页，串行翻译指定范围
- 显示范围任务进度，并可在当前页完成后停止
- 在原图与译图之间切换
- 本地缓存已经完成的译图，避免重复消耗时间和 API
- 在软件内配置 DeepSeek API Key 和模型
- 默认使用 `deepseek-v4-flash`，明确关闭思考模式
- 软件内一键初始化 Windows 翻译环境
- 自动准备 Python、隔离环境、检测/OCR/擦字依赖及默认模型
- 初始化完成后由 JHenTai 自动启动本地翻译服务

## 下载

请从 [Releases](https://github.com/Riderich/JHenTai-Image-Translation/releases) 下载最新的 Windows 预发布版。

当前测试版：

- [漫画图片翻译 v0.1.0 Alpha 2（一键初始化测试版）](https://github.com/Riderich/JHenTai-Image-Translation/releases/tag/v0.1.0-image-translation-alpha.2)

下载后必须**完整解压**，不要直接在压缩包中运行程序。目录中的 `app`、`translation_service` 和 `translation_engine` 都是初始化所需内容。

## 首次初始化

1. 运行 `app/jhentai.exe`。
2. 打开 **设置 → 漫画翻译**。
3. 点击 **初始化翻译环境**。
4. 等待软件自动安装独立 Python 环境、图片处理依赖和默认模型。
5. 初始化完成后，状态会变成“翻译服务已就绪”。
6. 填写自己的 DeepSeek API Key，保存设置并测试连接。

初始化预计下载约 **4–7 GB**，建议至少预留 **12 GB** 可用空间。网络速度、PyTorch 依赖和模型下载会显著影响耗时。下载中断后可以点击重试，已经下载或安装的内容会尽量复用。

当前 Alpha 版默认采用 CPU 兼容模式。NVIDIA GPU 加速选择和更完整的安装恢复机制仍在开发中。

## 翻译漫画

1. 在 JHenTai 中打开一本漫画并进入阅读界面。
2. 打开顶部菜单，点击翻译图标。
3. 选择 **翻译当前页**，或者选择 **翻译页面范围…**。
4. 等待检测、OCR、DeepSeek 翻译、擦字和中文嵌字完成。
5. 使用菜单中的 **显示原图/显示译图** 检查效果。

范围翻译每次只处理一页，避免同时占用过多内存、显存和 API 请求。已经成功缓存的页面会自动跳过。

## 工作流程

```text
漫画原图
  → 本机文字区域检测
  → 本机日文 OCR
  → DeepSeek API 翻译识别出的文字
  → 本机擦除原文
  → 本机排版并嵌入中文
  → 缓存并显示完整译图
```

图片处理通过本机 `127.0.0.1` 服务完成。DeepSeek API Key 保存在 JHenTai 的本机配置中，并随翻译请求传给本机服务；DeepSeek 接收需要翻译的文字。请勿把本项目的本地 HTTP 服务暴露到公网，也不要把自己的 Key 写入源码、日志或 Issue。

## 资源消耗

| 阶段 | 主要资源 | 说明 |
|---|---|---|
| 初始化 | 网络、磁盘、CPU | 安装 Python/PyTorch 依赖并下载模型，耗时最长 |
| 文字检测与 OCR | CPU、内存 | 当前测试版默认使用 CPU，漫画分辨率越高耗时越长 |
| DeepSeek 翻译 | 网络、API 额度 | 只负责机器翻译，已关闭思考模式 |
| 擦字与中文嵌字 | CPU、内存 | 在本机生成最终译图 |
| 译图缓存 | 磁盘 | 已翻译页面会保存在 JHenTai 数据目录中 |

## 已知限制

- 当前只发布 Windows x64 一键初始化测试包
- 首次初始化下载量大，部分网络环境可能需要重试
- 默认 CPU 模式速度较慢
- Clash 系统代理、TUN/虚拟网卡或安全软件可能影响 Python、模型和 DeepSeek 连接
- OCR、气泡检测、擦字与排版仍可能出现错误
- DeepSeek Key 当前保存在本机应用配置中，尚未接入系统凭据保险库
- 安卓端需要独立的移动推理实现，不能直接把 Windows/Python 后端打包进 APK

## 开发状态

主要开发分支：`feature/image-translation`

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

本仓库是在以下开源项目基础上进行的实验性开发：

- [JHenTai](https://github.com/jiangtian616/JHenTai)：跨平台 E-Hentai/ExHentai 客户端与阅读器界面
- [manga-image-translator](https://github.com/zyddnys/manga-image-translator)：文字检测、OCR、翻译、擦字和嵌字流程
- [DeepSeek](https://www.deepseek.com/)：可选的在线机器翻译模型服务

本项目名称中的 JHenTai 用于说明技术来源和兼容关系，不代表获得原项目官方背书。

## 许可证

本仓库继续遵循 [Apache License 2.0](LICENSE)。上游依赖、模型、字体和第三方服务分别适用其各自的许可证及使用条款。

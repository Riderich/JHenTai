# iOS 独立漫画翻译架构与测试清单

## 目标

iOS 版与 Android v1.1 使用同一产品逻辑：OCR、擦字和中文嵌字在手机本地完成，只把识别出的文字发送到用户配置的 OpenAI 兼容 API。iOS 不依赖 Windows、本地 HTTP 服务或桌面端初始化环境。

## 数据流

1. Flutter 阅读器取得当前漫画页的原始图片字节。
2. `MobileImageTranslationService` 通过 MethodChannel 请求原生 OCR。
3. iOS `ImageTranslationPlugin` 使用 Vision 的精确识别模式，返回文字和像素坐标。
4. Dart 将文字批量发送给配置的翻译 API，并要求按原顺序返回 JSON 字符串数组。
5. Dart 把译文和原坐标交回原生层。
6. iOS 使用 UIKit/Core Graphics 覆盖原文字区域并绘制中文，返回 PNG。
7. Flutter 把 PNG 写入译图缓存；阅读器负责原图/译图切换、当前页和范围翻译。

漫画图片不会发送给翻译 API。用户的 API Key 只保存在应用本地配置中。

## MethodChannel 协议

通道名称：`top.jtmonster.jhentai.image_translation`

### `recognizeJapanese`

输入：

```text
{
  image: Uint8List
}
```

输出：

```text
[
  {
    text: String,
    x: Int,
    y: Int,
    width: Int,
    height: Int,
    confidence: Double? // iOS 提供，Dart 当前不依赖
  }
]
```

坐标以图片左上角为原点，单位为原始图片像素。iOS Vision 的左下角归一化坐标必须在原生层转换，不能交给 Dart 处理。

### `renderTranslations`

输入：

```text
{
  image: Uint8List,
  regions: [
    {
      text: String,
      translation: String,
      x: Int,
      y: Int,
      width: Int,
      height: Int
    }
  ]
}
```

输出：PNG `Uint8List`。

Android 与 iOS 必须保持这一协议一致，以便 Dart 层只维护一个移动翻译服务。

## 平台实现

- Android：ML Kit Japanese Text Recognition + Bitmap/Canvas。
- iOS：Vision `VNRecognizeTextRequest` + UIKit/Core Graphics。
- Windows：继续调用本机翻译 HTTP 服务，支持 OCR/修复/本地 NLLB/CUDA。

iOS 启动时会查询当前 Vision revision 支持的语言；不支持 `ja-JP` 时明确返回错误，不静默退回英文 OCR。若真机测试发现竖排漫画识别明显弱于 Android，再评估将 iOS OCR 替换为 ML Kit，Dart 和渲染协议无需变化。

## 线程和内存

- Vision OCR 和图片渲染在串行高优先级后台队列执行，避免阻塞 Flutter 主线程。
- Flutter 回调统一切回主线程。
- 渲染保持原图像素尺寸并输出 PNG。测试超长页面时应观察内存峰值；必要时再加入图片尺寸上限或分块渲染。
- 阅读器的页面范围翻译继续按现有队列执行，不同时启动整本漫画翻译。

## 身份与分发

- Bundle ID：`com.riderich.jhentai.translation`
- 显示名称：`JHenTai 翻译版`
- 原仓库中的开发团队 ID 已移除，首次在 Mac 打开时由发布者选择自己的 Apple Developer Team。
- GitHub Actions 的 `Build iOS Translation` 工作流只产生 unsigned IPA artifact，不自动创建 Release。
- TestFlight、注册设备 IPA 或 App Store 分发需要在 macOS/Xcode 中配置 Apple 证书和 Provisioning Profile。

## macOS 首次编译

```bash
git fetch origin
git switch feature/ios-image-translation
flutter pub get
cd ios
pod install --repo-update
open Runner.xcworkspace
```

在 Xcode 中选择 Runner Target → Signing & Capabilities：

1. 选择自己的 Team。
2. 确认 Bundle ID 可注册；如已被占用，统一修改三套 Build Configuration。
3. 先选择 iOS Simulator 编译，再连接真机并启用 Developer Mode。
4. 真机运行前确认系统语言包支持日文 Vision OCR。

## 明日真机测试顺序

1. 冷启动：检查日志目录、首页和设置页无崩溃。
2. 设置页：iOS 不显示 Windows 服务/NLLB/CUDA，只显示手机独立 API 配置。
3. 空 Key：DeepSeek 地址下点击测试连接，应直接提示填写 Key，不发送网络请求。
4. API：保存 Key 后测试 `deepseek-v4-flash` 非思考模式。
5. OCR：分别测试横排、竖排、拟声词和低清扫描页。
6. 单页：长按图片翻译当前页，检查坐标方向、白底覆盖和中文排版。
7. 切换：原图/译图切换和重新翻译正常。
8. 范围：测试 2–3 页范围、停止任务、失败计数和缓存复用。
9. 内存：测试一张超长页和连续十页，观察 Xcode Memory Graph 与系统终止日志。
10. 网络：Wi-Fi/蜂窝切换、Clash/VPN、超时和错误提示。

## 发布前门槛

- GitHub Actions unsigned iOS 构建成功。
- 至少一台 iPhone 真机完成上述单页和范围测试。
- 确定长期 Bundle ID、签名证书和升级策略。
- 将版本号更新为 v1.2.0，并在 Release 中区分 unsigned IPA、TestFlight 或注册设备构建。

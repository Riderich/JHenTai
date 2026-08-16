# 贡献指南

感谢你愿意帮助改进 JHenTai Image Translation。

## 提交问题

- 功能异常请使用 Bug 模板，并提供可复现步骤、软件版本和设备信息。
- 新功能建议请使用功能建议模板，说明使用场景，而不只是实现方案。
- 不要提交 API Key、Cookie、访问令牌、私人漫画图片或包含隐私的完整日志。
- 本项目是社区衍生版本，翻译功能相关问题请勿提交到上游 JHenTai。

## 开发流程

1. Fork 本仓库并从最新开发分支创建功能分支。
2. 只修改与目标功能有关的文件，避免混入自动生成或本地运行数据。
3. 保持现有 Dart/Flutter 代码风格，提交前运行格式化和相关检查。
4. Windows 功能至少完成一次 Release 构建；翻译服务改动还应验证 Python 语法和补丁可应用性。
5. 提交 Pull Request，说明改动内容、验证方式、界面变化及已知限制。

## 常用检查

```powershell
dart format --set-exit-if-changed lib
flutter analyze
flutter test
flutter build windows --release -t lib/src/main.dart
```

翻译引擎兼容改动保存在 `translation_service/manga-image-translator.patch`。修改引擎后，请同步更新该补丁并验证它可应用到对应上游版本。

提交代码即表示你同意贡献内容按仓库的 Apache License 2.0 发布。第三方模型、字体和服务仍遵循其各自许可证及条款。

# 安全说明

## 支持版本

安全修复优先覆盖最新正式版。请先确认问题仍能在 [最新 Release](https://github.com/Riderich/JHenTai-Image-Translation/releases/latest) 中复现。

## 报告安全问题

请不要公开发布包含 API Key、Cookie、访问令牌、私人漫画内容或可直接利用细节的 Issue。优先使用 GitHub 仓库的 **Security → Report a vulnerability** 私密报告功能；如果该入口暂不可用，请只创建不含敏感细节的 Issue，请求维护者提供私密沟通方式。

报告中建议包含：

- 受影响版本与 Windows 版本
- 问题类型和影响范围
- 最小复现步骤
- 已确认不会泄露真实凭据的日志或截图
- 可行的缓解建议（如有）

本地翻译服务默认只监听 `127.0.0.1`。不要将其转发或暴露到公网，也不要把 API Key 写入源码、日志或问题报告。

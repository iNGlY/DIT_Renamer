# DIT Renamer 1.3.0 GitHub 发布要求

- 标签：`v1.3.0`
- 标题：`DIT Renamer 1.3.0`
- 构建号：`1300`
- 合并经过验证的菜单栏后台工作流，并包含重复建议名自动 `_1` 分配、隐藏卷身份过滤、拔卡待办清理和可关闭的 DJI 自动挂载。
- 菜单栏、审批协调器、自动队列、DJI、卷过滤、Sony、ARRI、Sidecar、审计、双卡模拟及双架构类型检查必须通过。
- DMG 必须包含 `/Applications` 快捷方式；ZIP/DMG、SHA256SUMS、LICENSE 与 NOTICE 必须上传。
- 标签与 Source Code 不得包含 `.agents`、AGENTS/HANDOFF、本地绝对路径、密钥、聊天记录或未提交的 Printer 工作。
- 发布后生成签名 `docs/appcast.xml`，将 `1.3.0 (1300)` 设为 Sparkle 最新更新，并验证 GitHub Pages 与应用内更新发现。

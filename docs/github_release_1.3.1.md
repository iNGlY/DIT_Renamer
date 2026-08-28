# DIT Renamer 1.3.1 GitHub 发布要求

- 标签：`v1.3.1`
- 标题：`DIT Renamer 1.3.1`
- 构建号：`1301`
- 包含 Sony FX3 `Title + Date` 严格解析、首次人工卷号、历史自动递增、并发连续卷号预留和重挂载防重复待办。
- Sony、审批协调器、自动队列、卷过滤、ARRI、Sidecar、审计及双架构类型检查必须通过。
- DMG 必须包含 `/Applications` 快捷方式；ZIP/DMG、SHA256SUMS、LICENSE 与 NOTICE 必须上传。
- 发布源码不得包含本地绝对路径、密钥、聊天记录或未提交的 Printer 工作。
- 发布后生成签名 `docs/appcast.xml`，将 `1.3.1 (1301)` 设为 Sparkle 最新更新，并验证 GitHub Pages 与应用内更新发现。

# DIT Renamer 1.2.2 GitHub 发布要求

- 标签：`v1.2.2`
- 标题：`DIT Renamer 1.2.2`
- 构建号：`1202`
- 只包含菜单栏忽略卷同步修复、回归测试和相应双语文档。
- `MenuBarIgnoredVolumeTests`、审批队列、卷过滤回归、双架构 typecheck 和 universal 构建必须通过。
- DMG 必须包含 `/Applications` 快捷方式；ZIP/DMG、SHA256SUMS、LICENSE 与 NOTICE 必须上传。
- 标签与 Source Code 不得包含 `.agents`、AGENTS/HANDOFF、本地绝对路径、密钥或未提交的 Printer 工作。
- 发布后生成签名 `docs/appcast.xml`，将 `1.2.2 (1202)` 设为 Sparkle 最新更新。

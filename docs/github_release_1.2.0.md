# DIT Renamer 1.2.0 GitHub 发布要求

## 发布定位

- Git 标签：`v1.2.0`
- GitHub Release 标题：`DIT Renamer 1.2.0`
- Universal Swift 应用，支持 macOS 14+、Apple Silicon 与 Intel Mac。
- 当前资产使用 ad-hoc 签名且未 notarize。Release 与 README 必须保留首次启动的 Gatekeeper 说明。

## 核心验收

- Swift arm64/x86_64 类型检查与 universal 构建通过。
- Sony FX3 `PRIVATE/M4ROOT/CLIP` + MP4、FX6 `XDROOT/Clip` + MXF 夹具通过。
- 同 UUID、不同 BSD 节点和不同首末素材的双卡保持独立，并严格串行自动处理。
- 同 UUID、相同首末素材的疑似克隆卡不得自动或批量批准。
- 两份克隆 exFAT 镜像同时以 `Untitled` 挂载时，第二张即使位于 `/Volumes/Untitled 1`，仍按真实 VolumeName 识别，并完成真实 `diskutil` 重命名、强制卸载、重挂载及 UUID/卷名复核。
- App、Sparkle 嵌套组件与 DMG 严格签名验证通过，DMG 包含 `/Applications` 快捷方式。
- `docs/appcast.xml` 必须只指向公开的 1.2.0 ZIP，EdDSA 签名、长度与下载 SHA-256 一致。
- 默认分支、远程分支、当前发布标签与 Source Code 归档不得包含 Agent、handoff、对话导出、本地绝对路径、密钥或其它项目资料；Printer 仅保留独立项目本身及 Renamer 只读接口。

## 发布顺序

1. 提交并将正式版提交快进到 `main`。
2. 构建 `1.2.0 (1200)` ad-hoc universal App、ZIP 与 DMG。
3. 推送 `main`，创建 `v1.2.0` Latest Release 并上传资产。
4. 使用钥匙串中的 Sparkle EdDSA 私钥生成 appcast，提交并推送 `docs/appcast.xml`。
5. 从 GitHub 下载 ZIP，与本地文件和 appcast enclosure 核对；使用旧版 App 指向测试 feed 验证发现、下载与安装。

## 安全边界

DIT Renamer 只在拷贝开始前执行卷重命名及同一分区的强制重挂载，不复制、不校验、不擦除素材。系统级模拟使用 `/tmp` 下的可丢弃磁盘镜像，不接触真实摄影机卡。

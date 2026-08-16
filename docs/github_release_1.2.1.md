# DIT Renamer 1.2.1 GitHub 发布要求

## 发布定位

- Git 标签：`v1.2.1`
- GitHub Release 标题：`DIT Renamer 1.2.1`
- 构建号：`1201`
- Universal Swift 应用，支持 macOS 14+、Apple Silicon 与 Intel Mac。
- 资产使用 ad-hoc 签名且未 notarize；README 与 Release Notes 必须保留首次启动的 Gatekeeper 图形界面说明。

## 核心验收

- 全部 Renamer 测试、Swift arm64/x86_64 类型检查与 universal 构建通过。
- ARRI ALE、Sony NonRealTimeMeta、Panasonic P2、Canon XML/XMP、RED RMD、DJI SRT/XMP、Nikon N-RAW 与 Blackmagic BRAW 解析器测试通过。
- Canon NewsML/NewsItem/NewsMetadata、镜头字段、调色 sidecar 和冲突型号不得升格为具体摄影机型号。
- RED RDC/R3D 不得被 Nikon 文件名规则捕获；DJI CinemaDNG 不得被判为照片卡或硬编码为 Ronin 4D；`.NEV` 与 `.braw` 不得在无可靠字段时猜测机型。
- Sony FX3 `PRIVATE/M4ROOT/CLIP` + MP4、FX6 `XDROOT/Clip` + MXF、ARRI UDF/HDE 与 Panasonic P2 fixture 通过。
- 同 UUID、不同 BSD 节点和不同首末素材的双卡保持独立，并严格串行执行；重复目标卷名继续要求人工分配 `_1`、`_2` 或其他卷号。
- App、Sparkle 嵌套组件与 DMG 的 ad-hoc 签名验证通过；DMG 包含 `/Applications` 快捷方式。
- `docs/appcast.xml` 只指向公开的 1.2.1 ZIP，EdDSA 签名、长度与下载 SHA-256 一致。
- 默认分支、标签、Source Code 和发布资产不得包含 `.agents`、AGENTS/HANDOFF、对话导出、本地绝对路径、密钥、Printer 未提交工作或其它项目资料。

## 发布顺序

1. 明确暂存全部 Renamer 1.2.1 文件并排除 `Printer/`，提交后将 `main` 快进到该提交。
2. 构建 `1.2.1 (1201)` ad-hoc universal App、ZIP 与 DMG。
3. 推送 `main`，创建 `v1.2.1` Latest Release 并上传 DMG、ZIP、`SHA256SUMS.txt`、`LICENSE` 与 `NOTICE`。
4. 使用 Sparkle EdDSA 私钥生成并提交 `docs/appcast.xml`，推送 `main`。
5. 从 GitHub 下载 ZIP/DMG，核对 SHA-256、架构、签名、DMG 的 Applications 快捷方式和在线更新发现/下载安装。

## 安全边界

DIT Renamer 只在拷贝开始前执行卷重命名和同一分区的强制重挂载，不复制、不校验、不擦除素材。系统级模拟只使用 `/tmp` 下的可丢弃磁盘镜像，不对真实摄影机卡执行重命名、卸载或重挂载。

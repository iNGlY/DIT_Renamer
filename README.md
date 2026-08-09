# DIT Renamer 1.1

DIT Renamer 是基于 Swift 构建的 macOS 现场 DIT 工具，用于识别可移除摄影机媒体、生成卷名建议并记录重命名审计信息。大部分功能实现代码由 AI 完成。

**下载当前版本：[DIT Renamer 1.1 Release](https://github.com/iNGlY/DIT_Renamer/releases/latest)**

## 运行边界

- 只处理 macOS 报告为可移除且非内置的已挂载卷。
- 在重命名前复核挂载路径、BSD 分区节点、Volume UUID，并在可用时复核 Media UUID。
- 重命名成功后仅针对已复核的同一 BSD 分区执行强制卸载、重挂载和 UUID/卷名复核；操作前必须停止会持续访问该卷的任务。
- 未完成扫描、未识别媒体、空卡、照片卡、未配置机位或残留旧素材不会进入自动重命名队列。
- 所有自动命名都应视为建议；厂商目录结构和机型证据不足时必须人工确认。

## 项目结构

```text
DIT_Renamer/
├── src_swift/             # Swift 源码
│   ├── Models/            # 语言和审计持久化
│   ├── Views/             # SwiftUI 界面
│   ├── MediaScanner.swift # 媒体目录扫描
│   ├── VolumeMonitor.swift# 可移除卷监控
│   └── RenamerEngine.swift# BSD/UUID 复核与重命名
├── docs/                  # DIT 现场相关说明与研究记录
└── scripts/build_swift_app.sh
```

## 构建

需要 macOS 14 或更高版本和 Apple Swift 编译器。正式分发还需要 Developer ID Application 证书，以及已保存到钥匙串的 notarytool profile。构建前建议对两个架构运行类型检查：

```bash
swiftc -typecheck -target arm64-apple-macosx14.0 $(find src_swift -name '*.swift' -print)
swiftc -typecheck -target x86_64-apple-macosx14.0 $(find src_swift -name '*.swift' -print)
bash -n scripts/build_swift_app.sh
```

首次发布前，将 Apple notarization 凭据保存到钥匙串：

```bash
xcrun notarytool store-credentials "DITRenamer-Notary" --apple-id "APPLE_ID" --team-id "TEAM_ID"
```

生成 universal（arm64 + x86_64）的 1.1 `.app`、`.zip` 和 `.dmg`：

```bash
export DIT_RENAMER_SIGNING_IDENTITY="Developer ID Application: Team Name (TEAMID)"
export DIT_RENAMER_NOTARY_PROFILE="DITRenamer-Notary"
./scripts/build_swift_app.sh
```

脚本会在构建前验证签名身份和 notarization profile，不会回退到 ad-hoc 签名。它会分别公证并 staple App 与 DMG，随后使用本机 Gatekeeper `spctl` 验证；只有全部步骤通过后才替换 `Release/`。发布镜像中不包含 `sudo xattr`、隔离属性清除命令或 Gatekeeper 绕过工具。

缺少 Developer ID 时，可显式生成仅供 GitHub 预发布或内部测试的 universal ad-hoc 包：

```bash
DIT_RENAMER_RELEASE_MODE=adhoc ./scripts/build_swift_app.sh
```

该模式不会调用 notarization、staple 或 Gatekeeper 通过检查，资产名称会包含 `adhoc-unnotarized`，DMG 内也会明确标注风险。它不会成为静默回退路径；默认构建仍严格要求 Developer ID。由于 GitHub 下载会附带 quarantine 属性，ad-hoc 构建无法保证普通用户双击即开，不应标记为正式稳定版。

GitHub 发布需求、发布说明和操作流程见 [`docs/github_release_1.1.md`](docs/github_release_1.1.md)。完成 GitHub CLI 登录并配置 `origin` 后，可使用 `scripts/publish_github_release.sh` 校验资产、推送分支与 `v1.1.0` 标签，并创建 GitHub Latest Release。

输出只写入项目内的 `build_swift/` 和 `Release/`，这两个目录属于生成物，不是源代码输入。

## 现场提示

重命名是卷级元数据操作。执行前应停止会持续访问该卷的拷贝、校验或媒体管理任务；程序自身不会替现场人员判断 Silverstack、Finder 或其他进程是否仍在使用媒体。拔卡、换卡或设备节点变化后，必须重新选择并扫描卷。

厂商命名规则、媒体结构和同类软件能力的核对结果见 [`docs/research_swift_1.1_vendor_rules.md`](docs/research_swift_1.1_vendor_rules.md)。

## 许可证与署名

Copyright 2026 DIT247。项目采用 [Apache License 2.0](LICENSE) 发布，原始发布者与官方来源记录在 [NOTICE](NOTICE) 中。

允许个人及商业使用、修改和再分发，但分发源码或二进制及其衍生版本时必须遵守 Apache-2.0，包括保留许可证、相关版权声明和 NOTICE 中的 DIT247 原始发布者信息，并对修改过的文件作出说明。本许可证不授予第三方冒充官方版本或超出合理来源说明范围使用 DIT247 名称与产品标识的权利。

# DIT Renamer 1.1.1

DIT Renamer 是基于 Swift 构建的 macOS 现场 DIT 工具，用于识别可移除摄影机媒体、生成卷名建议并记录重命名审计信息。大部分功能实现代码由 AI 完成。

**下载当前版本：[DIT Renamer 1.1.1 Release](https://github.com/iNGlY/DIT_Renamer/releases/latest)**

## 首次安装（macOS）

1. 从 [Latest Release](https://github.com/iNGlY/DIT_Renamer/releases/latest) 下载 DMG，并使用 `SHA256SUMS.txt` 校验下载的 DMG 或 ZIP。
2. 双击 DMG。在打开的窗口中，将 `DIT Renamer.app` 拖到旁边的 `Applications` 快捷方式上；不要把 App 放在 DMG 内，也不要从下载目录直接长期运行。
3. 从 `/Applications/DIT Renamer.app` 启动。由于当前版本没有 Developer ID 和 notarization，macOS 可能第一次阻止启动；此时打开“系统设置 > 隐私与安全性”，确认 DIT Renamer 后选择“仍要打开”。
4. 首次启动完成后，应用会在原安装路径检查更新。以后更新由 Sparkle 替换原 App 并重启，不需要再次拖拽 App。
5. 首次接入摄影机卡前，先停止 Silverstack、Finder 和其他会访问该卡的程序，并在可丢弃测试卡上确认现场流程。应用会强制卸载并重挂载重命名后的卡。

当前免费发布包是 universal ad-hoc 测试版，不保证在所有 macOS 设备上绕过 Gatekeeper。项目不提供 `sudo xattr`、隔离属性清除或绕过 Gatekeeper 的脚本。

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

生成 universal（arm64 + x86_64）的 1.1.1 `.app`、`.zip` 和 `.dmg`：

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

### 在线更新（免费 ad-hoc 模式）

应用内置 Sparkle 2.9.5。首次安装需要用户将 `DIT Renamer.app` 放入 `/Applications` 或 `~/Applications` 并允许 macOS 打开一次；后续启动时会后台检查 GitHub Pages 的 appcast，只有发现更新才显示提示。用户点击更新后，Sparkle 会在原路径验证并替换整个 App，完成后用户只需点击重新启动，不需要再次拖拽 App。

Sparkle 发行包由 `scripts/bootstrap_sparkle.sh` 固定下载并校验 SHA-256，依赖保存在被忽略的 `.deps/`。发布更新归档前，使用 `scripts/generate_appcast.sh <更新归档目录>` 生成 EdDSA 签名 appcast；EdDSA 私钥只保存在本机钥匙串，不得提交仓库。更新不会在卷重命名、强制卸载或重挂载事务中安装，更新后还会验证目标 `CFBundleVersion`，失败时保留旧版本。

无 Developer ID 时，后续替换流程可以工作，但 Gatekeeper 仍可能要求用户手动允许打开；这不是 Sparkle EdDSA 能消除的限制。

GitHub 发布需求、发布说明和操作流程见 [`docs/github_release_1.1.1.md`](docs/github_release_1.1.1.md)。完成 GitHub CLI 登录并配置 `origin` 后，可使用 `scripts/publish_github_release.sh` 校验资产、推送分支与 `v1.1.1` 标签，并创建 GitHub Latest Release；更新 appcast 由 `scripts/generate_appcast.sh` 生成。

输出只写入项目内的 `build_swift/` 和 `Release/`，这两个目录属于生成物，不是源代码输入。

## 现场提示

重命名是卷级元数据操作。执行前应停止会持续访问该卷的拷贝、校验或媒体管理任务；程序自身不会替现场人员判断 Silverstack、Finder 或其他进程是否仍在使用媒体。拔卡、换卡或设备节点变化后，必须重新选择并扫描卷。

厂商命名规则、媒体结构和同类软件能力的核对结果见 [`docs/research_swift_1.1_vendor_rules.md`](docs/research_swift_1.1_vendor_rules.md)。

## 许可证与署名

Copyright 2026 DIT247。项目采用 [Apache License 2.0](LICENSE) 发布，原始发布者与官方来源记录在 [NOTICE](NOTICE) 中。

允许个人及商业使用、修改和再分发，但分发源码或二进制及其衍生版本时必须遵守 Apache-2.0，包括保留许可证、相关版权声明和 NOTICE 中的 DIT247 原始发布者信息，并对修改过的文件作出说明。本许可证不授予第三方冒充官方版本或超出合理来源说明范围使用 DIT247 名称与产品标识的权利。

---

# DIT Renamer 1.1.1

DIT Renamer is a native Swift macOS DIT tool for identifying removable camera media before copying begins, suggesting volume names, and recording rename audit data. Most feature implementation code was written by AI.

**Download the current version: [DIT Renamer 1.1.1 Release](https://github.com/iNGlY/DIT_Renamer/releases/latest)**

## First Installation on macOS

1. Download the DMG from the [Latest Release](https://github.com/iNGlY/DIT_Renamer/releases/latest), then verify the downloaded DMG or ZIP with `SHA256SUMS.txt`.
2. Open the DMG. In the window that appears, drag `DIT Renamer.app` onto the `Applications` shortcut. Do not leave the app inside the DMG or run it permanently from Downloads.
3. Launch `/Applications/DIT Renamer.app`. Because this release is not signed with Developer ID and is not notarized, macOS may block the first launch. Open **System Settings > Privacy & Security**, locate the DIT Renamer notice, and choose **Open Anyway**.
4. After the first launch, the app checks for updates from its installed location. Later Sparkle updates replace the existing app in place and restart it; no further drag-and-drop is required.
5. Before using a camera card, stop Silverstack, Finder, and any other process accessing the card. Test the workflow with a disposable card first. The app force-unmounts and remounts a card after a successful rename.

The current free package is a universal ad-hoc test release. Gatekeeper may still require manual approval. The project does not provide `sudo xattr`, quarantine-clearing, or Gatekeeper-bypass scripts.

## Scope and Safety

- Only mounted volumes reported by macOS as removable and non-internal are considered.
- Before renaming, the app rechecks the mount path, BSD partition node, Volume UUID, and Media UUID when available.
- After a successful rename, it force-unmounts and remounts only the verified partition, then checks its UUID, name, and mount point.
- Incomplete scans, unidentified media, empty cards, photo cards, unconfigured cameras, and cards with residual material are excluded from automatic renaming.
- Automatic names are suggestions. Camera directory evidence and model evidence must be reviewed by the operator when incomplete.

## Build and Release

The project requires macOS 14 or later and Apple Swift. The normal release build requires a Developer ID Application certificate and a notarization profile:

```bash
swiftc -typecheck -target arm64-apple-macosx14.0 $(find src_swift -name '*.swift' -print)
swiftc -typecheck -target x86_64-apple-macosx14.0 $(find src_swift -name '*.swift' -print)
bash -n scripts/build_swift_app.sh
```

Build a universal Developer ID release:

```bash
export DIT_RENAMER_SIGNING_IDENTITY="Developer ID Application: Team Name (TEAMID)"
export DIT_RENAMER_NOTARY_PROFILE="DITRenamer-Notary"
./scripts/build_swift_app.sh
```

Without Developer ID, explicitly build an ad-hoc test package:

```bash
DIT_RENAMER_RELEASE_MODE=adhoc ./scripts/build_swift_app.sh
```

The ad-hoc mode never silently replaces strict signing. Its assets include `adhoc-unnotarized` and the DMG contains a warning. Sparkle 2.9.5 is bundled for in-app updates; its EdDSA private key must remain in the publisher keychain or a protected external secret.

Release requirements and workflow: [`docs/github_release_1.1.1.md`](docs/github_release_1.1.1.md). Public update-feed generation: `scripts/generate_appcast.sh`.

## Project Layout

```text
DIT_Renamer/
├── src_swift/             # Swift source
│   ├── Models/            # Language, update, and audit persistence
│   ├── Views/             # SwiftUI interface
│   ├── MediaScanner.swift # Media directory scanning
│   ├── VolumeMonitor.swift# Removable-volume monitoring
│   └── RenamerEngine.swift# BSD/UUID checks and rename/remount
├── docs/                  # DIT workflow documentation and research
└── scripts/build_swift_app.sh
```

## License and Attribution

Copyright 2026 DIT247. The project is released under the [Apache License 2.0](LICENSE). Original publisher and source attribution are recorded in [NOTICE](NOTICE).

Personal and commercial use, modification, and redistribution are allowed under Apache-2.0. Distributed source or binary derivatives must retain the license, copyright notices, and DIT247 attribution in `NOTICE`, and must identify modified files. The license does not grant permission to present a derivative as an official DIT247 release or to misuse the DIT Renamer name and marks.

# DIT Renamer 1.1.1

DIT Renamer 是基于 Swift 构建的 macOS 现场 DIT 工具，用于识别可移除摄影机媒体、生成卷名建议并记录重命名审计信息。

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

### 在线更新（免费 ad-hoc 模式）

应用内置 Sparkle 2.9.5。首次安装需要用户将 `DIT Renamer.app` 放入 `/Applications` 或 `~/Applications` 并允许 macOS 打开一次；后续启动时会后台检查 GitHub Pages 的 appcast，只有发现更新才显示提示。用户点击更新后，Sparkle 会在原路径验证并替换整个 App，完成后用户只需点击重新启动，不需要再次拖拽 App。

更新归档使用 EdDSA 签名，更新不会在卷重命名、强制卸载或重挂载事务中安装，更新后还会验证目标版本；失败时保留旧版本。

无 Developer ID 时，后续替换流程可以工作，但 Gatekeeper 仍可能要求用户手动允许打开；这不是 Sparkle EdDSA 能消除的限制。

## 现场提示

重命名是卷级元数据操作。执行前应停止会持续访问该卷的拷贝、校验或媒体管理任务；程序自身不会替现场人员判断 Silverstack、Finder 或其他进程是否仍在使用媒体。拔卡、换卡或设备节点变化后，必须重新选择并扫描卷。

厂商命名规则、媒体结构和同类软件能力的核对结果见 [`docs/research_swift_1.1_vendor_rules.md`](docs/research_swift_1.1_vendor_rules.md)。

## 许可证与署名

Copyright 2026 DIT247。项目采用 [Apache License 2.0](LICENSE) 发布，原始发布者与官方来源记录在 [NOTICE](NOTICE) 中。

允许个人及商业使用、修改和再分发，但分发源码或二进制及其衍生版本时必须遵守 Apache-2.0，包括保留许可证、相关版权声明和 NOTICE 中的 DIT247 原始发布者信息，并对修改过的文件作出说明。本许可证不授予第三方冒充官方版本或超出合理来源说明范围使用 DIT247 名称与产品标识的权利。

---

# DIT Renamer 1.1.1

DIT Renamer is a native Swift macOS DIT tool for identifying removable camera media before copying begins, suggesting volume names, and recording rename audit data.

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

## License and Attribution

Copyright 2026 DIT247. The project is released under the [Apache License 2.0](LICENSE). Original publisher and source attribution are recorded in [NOTICE](NOTICE).

Personal and commercial use, modification, and redistribution are allowed under Apache-2.0. Distributed source or binary derivatives must retain the license, copyright notices, and DIT247 attribution in `NOTICE`, and must identify modified files. The license does not grant permission to present a derivative as an official DIT247 release or to misuse the DIT Renamer name and marks.

## 开发说明 / Development Note

本项目大部分功能性代码由 AI 完成。

Most functional code in this project was built with assistance from AI.

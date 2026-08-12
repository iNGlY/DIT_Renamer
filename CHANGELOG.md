# DIT Renamer 更新日志 / Changelog

## 1.2.0 Test — 2026-08-12

### 中文

- 按 Apple HIG 整理 App 与菜单栏图标，保留 `A247` App 图标，并统一采用经过 macOS 14 可用性验证的 SF Symbols。
- 增加菜单栏待审核数量、快速批准、手动指派、自动重命名开关和高置信度批量批准。
- 在侧边栏和“关于”窗口增加检查更新按钮；启动时静默探测新版，发现新版后显示目标版本，点击后展示更新内容并确认安装。
- 增加 Sony `M4ROOT`、`XDROOT`、MP4 和 MXF 回归覆盖，改善部分 CFexpress Type A 读卡器的外置介质识别。
- 修复重复 Volume UUID 的双卡运行时身份和审核队列冲突，仍在执行前复核 BSD 节点、Volume UUID 与可用的 Media UUID。
- 继续对 FAT、MS-DOS 和 exFAT 执行 11 字符卷名上限，并在成功重命名后强制卸载和重挂载同一分区。

### English

- Aligned App and menu-bar icons with Apple HIG, retained the `A247` App icon, and standardized interface symbols on SF Symbols verified for macOS 14.
- Added menu-bar review counts, quick approval, manual assignment, an auto-rename switch, and sequential batch approval for high-confidence cards.
- Added check-for-updates buttons to the sidebar and About window. Launch checks probe quietly; when a newer release is found, the target version is shown and release notes appear before installation confirmation.
- Added Sony `M4ROOT`, `XDROOT`, MP4, and MXF regression coverage and improved external-media recognition for some CFexpress Type A readers.
- Fixed runtime and approval-queue collisions for two cards that share a Volume UUID, while preserving BSD node, Volume UUID, and available Media UUID verification before execution.
- Continued enforcing the 11-character FAT, MS-DOS, and exFAT volume-name limit and force-remounting the same partition after a successful rename.

## 1.1.1 — 2026-08-10

### 中文

- 新增 Sparkle 2.9.5 应用内更新支持。首次安装后，更新可在原路径替换 App，并在用户确认后重新启动。
- 生成 universal binary，同时支持 Apple Silicon 与 Intel Mac。
- 保留重命名后的自动强制卸载、重挂载和 BSD/UUID 复核流程，解决 Silverstack 同名卡识别冲突。
- 增加是否保留检测到的 suffix 的手动选项，并继续执行 exFAT、FAT 和 MS-DOS 的 11 字符限制。
- 继续排除 Apple Disk Image Media、网络卷和系统虚拟卷。
- 保持 Sony XML/XMP 优先型号识别和可选 exiftool fallback。
- ParaShoot 报告支持跟随软件语言输出；`missingFiles: 0` 定义为校验通过，高置信度关联明细由用户选择是否输出。
- Renamer 对 DIT Printer 提供只读审计接口；Printer 不包含在本版本 App 中。
- 当前资产为 ad-hoc、未 notarize 版本，首次启动可能需要用户在 macOS 隐私与安全性设置中允许。

### English

- Added Sparkle 2.9.5 in-app updates. After the one-time installation, updates replace the app in place and restart it after user confirmation.
- Built a universal binary for Apple Silicon and Intel Macs.
- Preserved the forced unmount, remount, and BSD/UUID verification flow after renaming to address Silverstack same-name card conflicts.
- Added a manual option to keep a detected suffix while preserving the 11-character exFAT, FAT, and MS-DOS limit.
- Preserved hard filtering for Apple Disk Image Media, network volumes, and system virtual volumes.
- Preserved XML/XMP-first Sony model detection with optional exiftool fallback.
- ParaShoot reports follow the application language. `missingFiles: 0` is classified as verification passed, and high-confidence association details are opt-in.
- Renamer exposes a read-only audit interface to the separate DIT Printer; Printer is not included in this app package.
- The current assets are ad-hoc signed and not notarized. macOS may require manual approval on first launch.

## 1.1.0 — 2026-08-09

### 中文

- 首次公开 Swift 版本，面向 macOS 14+ 现场 DIT 工作流。
- 增加摄影机媒体识别、卷名建议、重命名审计和 Silverstack 同名卡处理流程。

### English

- First public Swift release for macOS 14+ on-set DIT workflows.
- Added camera-media identification, volume-name suggestions, rename auditing, and Silverstack same-name card handling.

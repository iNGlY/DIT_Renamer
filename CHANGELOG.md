# DIT Renamer 更新日志 / Changelog

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

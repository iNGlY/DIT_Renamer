# DIT Renamer 更新日志 / Changelog

## 1.2.0 — 2026-08-13

### 中文

- 按 Apple HIG 整理 App 与菜单栏图标，保留 `A247` App 图标，并统一采用经过 macOS 14 可用性验证的 SF Symbols。
- 增加菜单栏待审核数量、快速批准、手动指派、自动重命名开关和高置信度批量批准。
- 在侧边栏和“关于”窗口增加检查更新按钮；启动时静默探测新版，发现新版后显示目标版本，点击后展示更新内容并确认安装。
- 增加 Sony `M4ROOT`、`XDROOT`、MP4 和 MXF 回归覆盖，改善部分 CFexpress Type A 读卡器的外置介质识别。
- 修复重复 Volume UUID 的双卡运行时身份和审核队列冲突，仍在执行前复核 BSD 节点、Volume UUID 与可用的 Media UUID。
- 继续对 FAT、MS-DOS 和 exFAT 执行 11 字符卷名上限，并在成功重命名后强制卸载和重挂载同一分区。
- 默认在后台驻留菜单栏；加入通知、菜单栏卡片管理、规则切换和响应式主窗口。
- 修复同名双卡挂载时第二张卡因 `/Volumes/Untitled 1` 被误判为非通用卷名的问题，改用 `diskutil` 的真实 VolumeName。
- 自动重命名改为严格串行队列，避免两张卡同时完成扫描时第二张因忙碌状态被遗漏；重复挂载事件会合并。
- 相同 UUID 但首末素材不同的卡可分别自动处理；UUID 和首末素材都相同的疑似克隆卡必须人工确认。
- 增加中英双语、无需命令行的安装与故障排除教程，明确 macOS 14、无需额外运行库、可选 exiftool、权限与 Gatekeeper 图形界面处理流程。
- 增加挂载会话与扫描 generation 身份，快速换卡或取消重扫时旧结果不会进入新卡待办；拔卡候选立即失效。
- Media UUID 缺失时，执行前再次核对首末素材；重挂载最终复核允许最多 5 秒的系统登记延迟。
- 两张已挂载卡即使素材不同，只要建议或手动目标卷名相同，就同时停止自动和批量执行并要求人工加入 `_1`、`_2` 等冲突编号或分配其他卷号；自动队列首张执行前及连续两张之间增加 1 秒稳定窗口，并在每次执行前重新核对全部候选。
- 手动工作区增加“机位号重复”开关，自动生成当前可用的 `_1`、`_2` 等冲突编号；卡片复用次数改为默认关闭的可选审计/标签元数据，不再改变实际卷名，关闭时 PDF、CSV 与 Printer 只读接口均不输出该字段。

### English

- Aligned App and menu-bar icons with Apple HIG, retained the `A247` App icon, and standardized interface symbols on SF Symbols verified for macOS 14.
- Added menu-bar review counts, quick approval, manual assignment, an auto-rename switch, and sequential batch approval for high-confidence cards.
- Added check-for-updates buttons to the sidebar and About window. Launch checks probe quietly; when a newer release is found, the target version is shown and release notes appear before installation confirmation.
- Added Sony `M4ROOT`, `XDROOT`, MP4, and MXF regression coverage and improved external-media recognition for some CFexpress Type A readers.
- Fixed runtime and approval-queue collisions for two cards that share a Volume UUID, while preserving BSD node, Volume UUID, and available Media UUID verification before execution.
- Continued enforcing the 11-character FAT, MS-DOS, and exFAT volume-name limit and force-remounting the same partition after a successful rename.
- Moved the default workflow to a background menu-bar utility with notifications, mounted-card controls, rule switches, and a responsive main window.
- Fixed the second same-name card being treated as non-generic when macOS mounts it at `/Volumes/Untitled 1`; the app now uses `diskutil`'s real VolumeName.
- Added a strictly sequential automatic-rename queue so a second card is not skipped when two scans finish together; duplicate mount events are coalesced.
- Cards sharing a UUID remain auto-eligible when first/last clips differ. Exact UUID and clip-identity duplicates require operator review.
- Added a bilingual, Terminal-free installation and troubleshooting guide covering macOS 14, bundled dependencies, optional exiftool, permissions, and Apple's GUI Gatekeeper flow.
- Added mount-session and scan-generation identities so stale scan results cannot attach to a replacement card; candidates become stale as soon as their mount session disappears.
- When Media UUID is unavailable, the app rechecks first/last clip identity before execution. Final remount verification now tolerates up to five seconds of macOS registration delay.
- If two mounted cards resolve to the same suggested or manually requested volume name, automatic and batch execution stop for both cards until the operator appends `_1`, `_2`, and so on or assigns another roll. The queue now includes a one-second stabilization window before the first rename and between consecutive cards, followed by a fresh all-candidate safety check before every operation.
- Added a Duplicate Camera ID switch that assigns the next available `_1`, `_2`, and so on. Card reuse count is now optional audit/label metadata, disabled by default, never changes the real volume name, and is omitted from PDF, CSV, and the Printer read-only interface when disabled.

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

# DIT Renamer 1.2.0

DIT Renamer 是一款后台优先的原生 macOS 工具，帮助 DIT 在拷贝开始前识别摄影机卡、确认卷名，并为每次重命名留下记录。它只修改 macOS 显示的卷名，不改卡内目录或素材文件。

**[下载最新版本](https://github.com/iNGlY/DIT_Renamer/releases/latest)**

## 首次安装

1. 从 [Latest Release](https://github.com/iNGlY/DIT_Renamer/releases/latest) 下载 DMG。需要核对下载时，可使用同一发布页中的 `SHA256SUMS.txt`。
2. 打开 DMG，将 `DIT Renamer.app` 拖到旁边的 `Applications` 快捷方式。
3. 从 `/Applications/DIT Renamer.app` 启动。当前发布包没有 Developer ID 签名和 Apple 公证，macOS 可能在首次启动时阻止打开。此时前往“系统设置 > 隐私与安全性”，找到 DIT Renamer 并选择“仍要打开”。
4. 后续版本可由应用内更新直接替换。更新完成后只需重新启动，不必再次拖拽 App。

当前发布包是 universal ad-hoc 构建，支持 Apple Silicon 和 Intel Mac。项目不提供 `sudo xattr`、清除隔离属性或绕过 Gatekeeper 的脚本。

## 主要功能

- 只读扫描可移除摄影机媒体，并根据目录、素材名和可用元数据给出卷名建议。
- 默认驻留菜单栏并在后台监听新卡；只有需要人工确认、发生失败或用户主动打开时才显示主窗口。
- 允许人工调整机位、卷号、卡片复用次数，并选择是否保留检测到的 suffix。
- 对 FAT、MS-DOS 和 exFAT 卷名执行 11 字符上限，不会静默截断输入。
- 在菜单栏快速查看待人工审核的卡片，批准建议卷名，手动指派机位/卷号/复用次数/素材后缀，并可逐张批量批准高置信度卡片。
- 菜单栏可查看和忽略已挂载卡片、恢复忽略项、重新扫描、切换自动重命名、调整过滤规则、检查更新及打开设置。
- 重命名前复核挂载路径、BSD 分区节点、Volume UUID 和可用的 Media UUID；成功后强制卸载并重挂载同一分区，刷新 Silverstack 对同名卡的识别。
- 两张同名卡同时挂载时，使用真实卷标而不是 macOS 自动添加编号的挂载目录名；即使 Volume UUID 相同，也按 BSD 节点与首末素材分别处理，并严格串行执行重命名与重挂载。
- 优先从 Sony XML/XMP 读取具体机型；需要时可选用 exiftool 检查一条代表性素材，也可在设置中完全关闭。
- 覆盖 Sony FX3 的 `PRIVATE/M4ROOT/CLIP` + MP4 和 FX6 的 `XDROOT/Clip` + MXF 结构；具体型号仍以 XML/XMP 或可选 exiftool 元数据为准。
- 保存原卷名、新卷名、UUID、BSD 节点、首末素材和操作时间。
- 只读解析 ParaShoot 日志，并按软件当前语言导出中文或英文 PDF。`missingFiles: 0` 显示为“校验通过”；路径明确匹配时，可选择加入高置信度关联详情。
- 为检测到的 ARRIRAW 内容提供 HDE 容量参考。结果是估算值，不代表最终编码容量。
- 启动时检查更新；只有发现新版本才显示提示，重命名或重挂载期间不会安装更新。
- 主窗口按 720、900 和 1180 逻辑点宽度自适应布局，并保持 HiDPI 显示清晰；审计浏览和 PDF 导出保留在主窗口。

DIT Printer 是独立组件，不包含在 DIT Renamer 1.2.0 App 中。Renamer 只向 Printer 提供只读审计数据，Printer 不能通过该接口触发重命名、卸载、校验或擦除。

## 使用边界

- 只显示 macOS 标记为可移除、非内置且已经挂载的卷。
- Apple Disk Image Media、网络卷和系统虚拟卷始终排除。
- 扫描不完整、媒体无法识别、卡为空、只有照片、机位未配置或存在残留素材时，不进入自动重命名队列。
- `Untitled` 是 Sony FX3/FX6 等设备可能使用的默认卷名，不应直接用于备份盘。本软件处理的是摄影机卡，不负责为名为 `Untitled` 的备份盘提供服务。
- 卷名建议始终需要现场人员判断。厂商结构或机型证据不足时，应保留原卷名或手动输入。
- 当两张卡的 Volume UUID、首素材和末素材全部相同，软件会把它们视为疑似克隆介质，保留独立待办但禁止自动或批量批准，需要人工确认。

重命名前，停止 Silverstack、Finder 以及其他正在访问目标卡的任务。拔卡、换卡或设备节点变化后，应重新选择并扫描。先在可丢弃测试卡上验证工作流，再用于正式素材。

DIT Renamer 不复制素材，不执行传输 checksum 校验，也不擦除卡片。厂商命名规则和同类软件对比见 [摄影机媒体命名研究](docs/research_swift_1.1_vendor_rules.md)。

## 许可证与署名

Copyright 2026 DIT247。项目采用 [Apache License 2.0](LICENSE)，原始发布者与来源记录在 [NOTICE](NOTICE) 中。

允许个人和商业使用、修改及再分发。分发源码、二进制或衍生版本时，必须保留许可证、相关版权声明和 `NOTICE` 中的 DIT247 原始发布者信息，并说明修改内容。许可证不允许第三方把衍生版本表述为 DIT247 官方发布，或以超出合理来源说明的方式使用 DIT Renamer 名称与标识。

---

# DIT Renamer 1.2.0

DIT Renamer is a background-first native macOS utility that helps DITs identify camera cards, confirm volume names, and keep a record of every rename before offload begins. It changes the macOS volume name only; folders and clips on the card remain untouched.

**[Download the latest release](https://github.com/iNGlY/DIT_Renamer/releases/latest)**

## First installation

1. Download the DMG from [Latest Release](https://github.com/iNGlY/DIT_Renamer/releases/latest). Use `SHA256SUMS.txt` from the same page if you need to verify the download.
2. Open the DMG and drag `DIT Renamer.app` onto the `Applications` shortcut.
3. Launch `/Applications/DIT Renamer.app`. This release is not signed with Developer ID or notarized by Apple, so macOS may block the first launch. Open **System Settings > Privacy & Security**, find DIT Renamer, and choose **Open Anyway**.
4. Later releases can update the installed app in place. When an update finishes, restart the app; no further drag-and-drop installation is required.

The current package is a universal ad-hoc build for Apple Silicon and Intel Macs. This project does not provide `sudo xattr`, quarantine-removal, or Gatekeeper-bypass scripts.

## What it does

- Scans removable camera media without changing card contents, then suggests a volume name from folder, clip-name, and metadata evidence.
- Runs primarily from the menu bar and monitors for new cards in the background. The main window appears only for operator attention, failures, or an explicit request.
- Lets the operator adjust camera ID, roll number, card reuse count, and whether to keep a detected suffix.
- Enforces the 11-character FAT, MS-DOS, and exFAT volume-name limit without silently shortening input.
- Adds a menu-bar review panel for approving suggested names, assigning camera ID/roll/reuse/suffix values, and sequentially approving multiple high-confidence cards.
- The menu bar also exposes mounted-card actions, ignore/restore controls, rescanning, auto-rename, filtering rules, updates, and settings.
- Rechecks the mount path, BSD partition node, Volume UUID, and Media UUID when available. After a successful rename, it force-unmounts and remounts the same partition so Silverstack sees the new identity cleanly.
- When two same-name cards are mounted together, the app uses the real volume label instead of macOS's collision-suffixed mount-directory name. Cards sharing a Volume UUID remain distinct by BSD node and first/last clip evidence, and rename/remount operations run strictly in sequence.
- Reads Sony XML/XMP metadata first. Optional exiftool detection can inspect one representative clip when needed and can be disabled in Settings.
- Covers Sony FX3 `PRIVATE/M4ROOT/CLIP` + MP4 and FX6 `XDROOT/Clip` + MXF structures. Exact model labels still require XML/XMP or optional exiftool metadata.
- Records original and new names, UUIDs, BSD node, first and last clips, and operation time.
- Reads ParaShoot logs without modifying them and exports a Chinese or English PDF to match the app language. `missingFiles: 0` is shown as **Verification passed**; exact path matches can be included as optional high-confidence association details.
- Provides an HDE capacity reference for detected ARRIRAW media. The result is an estimate, not a promised encoded size.
- Checks for updates at launch and only prompts when a newer release is available. Updates are not installed during rename or remount operations.
- Adapts the main workspace at 720, 900, and 1180 logical-point widths while preserving HiDPI clarity. Audit browsing and PDF export remain in the main window.

DIT Printer is a separate component and is not included in the DIT Renamer 1.2.0 App. Renamer exposes read-only audit data to Printer; that interface cannot trigger rename, unmount, verification, or erase operations.

## Operating limits

- Only mounted volumes reported by macOS as removable and non-internal are shown.
- Apple Disk Image Media, network volumes, and system virtual volumes are always excluded.
- Incomplete scans, unidentified media, empty cards, photo-only cards, unconfigured camera IDs, and cards with residual material do not enter the automatic rename queue.
- `Untitled` may be the default volume name on cameras including the Sony FX3 and FX6. It should not be used as a backup-volume name; backup drives named `Untitled` are outside this application's scope.
- Every suggested name remains an operator decision. Keep the existing name or enter one manually when vendor or model evidence is incomplete.
- If two mounted cards share the same Volume UUID and the same first and last clip names, they remain separate review items but automatic and batch approval are disabled until an operator confirms them.

Before renaming, stop Silverstack, Finder, and any other process using the card. Select and scan again after a card is removed, replaced, or assigned a different device node. Test the workflow with a disposable card before using production media.

DIT Renamer does not copy clips, verify transfers, or erase cards. See [Camera Media Naming Research](docs/research_swift_1.1_vendor_rules.md) for vendor naming sources and workflow comparisons.

## License and attribution

Copyright 2026 DIT247. Released under the [Apache License 2.0](LICENSE), with original publisher and source attribution in [NOTICE](NOTICE).

Personal and commercial use, modification, and redistribution are permitted. Source, binary, and derivative distributions must retain the license, applicable copyright notices, and DIT247 attribution in `NOTICE`, and must identify modifications. The license does not allow a derivative to be presented as an official DIT247 release or to misuse the DIT Renamer name and marks.

## 开发说明 / Development note

本项目大部分功能性代码由 AI 协助完成。

Most functional code in this project was built with AI assistance.

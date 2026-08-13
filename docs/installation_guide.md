# DIT Renamer 安装与运行指南 / Installation and Troubleshooting Guide

本文面向不使用命令行的用户。正常安装、首次放行、权限设置和在线更新都可以在 Finder、系统设置或 DIT Renamer 内完成。

This guide is written for users who do not use Terminal. Normal installation, first-launch approval, permissions, and online updates can all be handled in Finder, System Settings, or DIT Renamer.

## 中文

### 1. 运行环境

| 项目 | 要求 |
| --- | --- |
| 操作系统 | macOS 14 Sonoma 或更高版本 |
| 处理器 | Apple Silicon 或 Intel；不需要 Rosetta |
| 安装位置 | 推荐 `/Applications/DIT Renamer.app` |
| 必需运行库 | 无；不需要 Swift、Python、Java、Homebrew |
| 可选工具 | exiftool，仅用于 XML/XMP 缺失时补充 Sony 机型识别 |
| 网络 | 首次安装不需要；检查更新和下载新版本时需要 |
| 权限 | 摄影机卡读写权限；可移动卷宗权限；通知权限可选 |

DIT Renamer 只支持 macOS。Windows、Linux、iPhone 和 iPad 不能运行本 App。macOS 13 或更早系统不会启动本版本，请先通过“系统设置 > 通用 > 软件更新”升级系统，或继续使用兼容的旧版。

### 2. 第一次安装

1. 打开仓库主页，点右侧 **Releases**，进入标有 **Latest** 的版本。
2. 下载文件名以 `.dmg` 结尾的安装镜像。不要下载 GitHub 自动生成的 Source code，也不要使用第三方重新打包的版本。
3. 双击下载完成的 DMG。
4. 在打开的窗口中，将 `DIT Renamer.app` 拖到 `Applications` 快捷方式上。
5. 等待复制完成，推出 DMG。
6. 打开 Finder > 应用程序。按住 Control 点按 DIT Renamer，选择“打开”，再确认一次“打开”。

当前免费分发版没有 Apple Developer ID 和 notarization。Apple 不允许未公证 App 在所有 Mac 上完全无提示启动；这不是缺少运行库。项目采用 Apple 提供的图形界面放行流程，不提供 `sudo`、`xattr` 或清除隔离属性的脚本。

### 3. 提示“无法验证开发者”或“未知开发者”

1. 先在 Finder > 应用程序中尝试打开 DIT Renamer 一次。
2. 打开“系统设置 > 隐私与安全性”。
3. 滚动到页面下方，在安全性区域找到关于 DIT Renamer 的拦截说明。
4. 点“仍要打开”，使用 Touch ID 或 Mac 登录密码确认。
5. 回到应用程序再次打开。这个批准通常只需要对当前已安装版本执行一次；后续由应用内更新替换时无需重新拖拽。

### 4. 提示“App 已损坏，无法打开”

先不要安装所谓“修复工具”，也不要复制陌生终端命令。

1. 将 `/Applications/DIT Renamer.app` 移到废纸篓。
2. 删除未完整下载的 DMG。
3. 回到本仓库的 **Latest Release** 重新下载 DMG，确认浏览器已完成下载。
4. 重新拖入 Applications，再按上一节使用“隐私与安全性 > 仍要打开”。
5. 如果系统设置没有出现“仍要打开”，请确认系统为 macOS 14 或更高版本、App 位于 Applications、下载来源是本仓库 Release。仍无法启动时，保留原始 DMG 和 macOS 提示截图；不要降低整台 Mac 的安全设置。

由于没有 Developer ID，个别受企业管理或安全策略限制的 Mac 可能禁止任何未公证软件。符合 Apple 安全模型且无需命令行的解决办法是由管理员批准此 App，或将来改用 Developer ID 公证版；本项目不会用脚本绕过组织策略。

### 5. 首次运行看不到窗口

1. DIT Renamer 默认在后台运行，正常情况下 Dock 中不会出现常驻图标。
2. 查看屏幕右上角菜单栏中的存储卡图标。
3. 点图标后，可查看卡片、待办、规则和更多设置。
4. 需要完整窗口时，在菜单栏面板中选择打开主窗口或设置。

### 6. 插卡后没有显示

按顺序检查：

1. Finder 中是否能看到卡片；如果 Finder 都看不到，请先检查读卡器、线材、供电和卡片。
2. macOS 若询问可移动卷宗访问，请选择“允许”。此前拒绝过时，进入“系统设置 > 隐私与安全性 > 文件与文件夹”，允许 DIT Renamer 访问可移动卷宗。
3. 打开菜单栏图标，在“卡片”中执行重新扫描。
4. 确认卡片不是 APFS、NTFS、UDF、Apple Disk Image Media、网络卷或被手动忽略的卷。可在“规则”或完整设置中查看过滤项。
5. 确认没有正在运行的 Silverstack 拷贝任务、Finder 文件传输或其它程序占用卡片。

### 7. Sony 机型没有显示得足够具体

DIT Renamer 先读取卡内 XML/XMP。FX3 的常见结构是 `PRIVATE/M4ROOT/CLIP` + MP4，FX6 的常见结构是 `XDROOT/Clip` + MXF。目录结构可以确认 Sony 媒体类型，但具体型号仍需要元数据。

如果 XML/XMP 不含型号，App 会提示可安装 exiftool。它不是必需运行库：

1. 仅在确实需要补充机型时安装。
2. 使用 exiftool 官方提供的 macOS 图形安装包，双击 `.pkg`，按安装器提示完成；不要求 Homebrew 或终端。
3. 重新打开 DIT Renamer，确认设置中的 exiftool 型号识别已启用，再重新扫描。
4. 不安装时仍可正常人工确认卷名；速度优先时可在设置中关闭 exiftool 检测。

### 8. 在线更新

1. App 启动时会静默检查版本，发现更新后才显示提示。
2. 也可从菜单栏“更多”或主窗口点“检查更新”。
3. 阅读中英文更新内容，点确认更新。
4. 等待下载和验证完成，点“重新启动”。Sparkle 会替换 Applications 中的旧 App，不需要再次拖拽。
5. 重命名、强制卸载或重挂载进行中时，更新会暂停，待卡片操作完成后再试。

如更新按钮找不到新版，请确认网络可访问 GitHub，稍后重试。首次安装必须手动拖入 Applications；只有安装了带 Sparkle 的版本后，后续更新才能自动替换。

### 9. 不建议采用的方法

- 不运行网上复制的 `sudo xattr`、`spctl --master-disable` 或关闭 Gatekeeper 的命令。
- 不安装声称能“修复损坏 App”的第三方清理工具。
- 不从第三方网盘、聊天附件或重打包站点下载 App。
- 不在 Silverstack 正在拷贝、Finder 正在传输或卡片正在写入时重命名。

## English

### 1. Requirements

| Item | Requirement |
| --- | --- |
| Operating system | macOS 14 Sonoma or later |
| Processor | Apple Silicon or Intel; Rosetta is not required |
| Install location | `/Applications/DIT Renamer.app` recommended |
| Required runtimes | None; no Swift, Python, Java, or Homebrew installation |
| Optional tool | exiftool, only for Sony model detection when XML/XMP is unavailable |
| Network | Not required for first launch; required for update checks/downloads |
| Permissions | Read/write camera-media access; removable-volume access; notifications optional |

DIT Renamer is macOS-only. This release will not run on macOS 13 or earlier. Update macOS in **System Settings > General > Software Update**, or remain on an older compatible DIT Renamer release.

### 2. First installation

1. Open the repository page and select **Releases**, then open the version marked **Latest**.
2. Download the `.dmg` file. Do not download GitHub's automatic Source code archives or a third-party repackaged copy.
3. Double-click the downloaded DMG.
4. Drag `DIT Renamer.app` onto the `Applications` shortcut.
5. Wait for the copy to finish and eject the DMG.
6. Open Finder > Applications. Control-click DIT Renamer, choose **Open**, and confirm **Open** again.

The free distribution is not signed with Apple Developer ID and is not notarized. Apple does not provide a completely silent first launch for an unnotarized App on every Mac. This is not a missing-runtime error. Use Apple's GUI approval flow below; the project does not provide `sudo`, `xattr`, quarantine-removal, or Gatekeeper-disabling scripts.

### 3. “Unidentified developer” or developer cannot be verified

1. Make one launch attempt from Finder > Applications.
2. Open **System Settings > Privacy & Security**.
3. Scroll down to the Security section and locate the DIT Renamer message.
4. Select **Open Anyway** and authenticate with Touch ID or your Mac login password.
5. Open DIT Renamer again.

### 4. “App is damaged and can't be opened”

Do not install a “repair” utility or paste an unfamiliar Terminal command.

1. Move `/Applications/DIT Renamer.app` to the Trash.
2. Delete the incomplete DMG.
3. Download the DMG again from this repository's **Latest Release** and wait for the browser to finish.
4. Copy a fresh App to Applications and use **Privacy & Security > Open Anyway** if offered.
5. If Open Anyway never appears, confirm macOS 14+, the Applications install location, and the official Release source. Managed Macs may prohibit all unnotarized software; the compliant GUI-only solution is administrator approval or a future Developer ID notarized build, not a security-bypass script.

### 5. No window appears after launch

DIT Renamer is a background-first menu-bar utility. It normally has no persistent Dock icon. Find the card icon in the upper-right menu bar, open it, and use the Cards, Review, Rules, or More sections. Open the full window only when needed.

### 6. A card does not appear

1. Confirm Finder can see the card; otherwise check the reader, cable, power, and media.
2. Choose **Allow** if macOS requests removable-volume access. If previously denied, open **System Settings > Privacy & Security > Files & Folders** and allow DIT Renamer to access removable volumes.
3. Open the menu-bar panel and rescan.
4. Check whether APFS, NTFS, UDF, Apple Disk Image Media, network volumes, or manually ignored paths are filtered by Rules or Settings.
5. Stop any Silverstack copy, Finder transfer, or other task using the card before renaming.

### 7. Sony model is not specific enough

DIT Renamer reads XML/XMP first. FX3 commonly uses `PRIVATE/M4ROOT/CLIP` + MP4, while FX6 commonly uses `XDROOT/Clip` + MXF. Folder structure identifies the media family, but an exact model still requires metadata.

If needed, use the official exiftool macOS installer package: double-click the `.pkg` and follow Installer. Homebrew and Terminal are not required. Without exiftool, manual naming and every core operation remain available. Disable exiftool detection in Settings when scan speed is the priority.

### 8. In-app updates

The App checks quietly at launch and only prompts when a newer version exists. You can also select **Check for Updates** from the menu bar or main window. Review the release notes, confirm, wait for verification, and select **Relaunch**. Sparkle replaces the App in Applications; no repeat drag-and-drop is needed. Updates pause while a rename or remount is active.

### 9. Avoid these methods

- Do not run copied `sudo xattr`, `spctl --master-disable`, or Gatekeeper-disabling commands.
- Do not install third-party “damaged App repair” tools.
- Do not download repackaged builds from file hosts or chat attachments.
- Do not rename while Silverstack, Finder, or the camera is writing to the card.

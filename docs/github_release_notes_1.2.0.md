# DIT Renamer 1.2.0

## 中文

DIT Renamer 1.2.0 是后台优先的正式版本，主要操作可直接在菜单栏完成。

本版本新增：

- 按 Apple HIG 重新整理 App、侧边栏和菜单栏图标；App 图标保留 `A247` 品牌助记，界面图标统一使用 macOS 14 可用的 SF Symbols。
- 菜单栏使用轻量的存储卡状态图标：无待办时为轮廓，存在待审核卡片时强化显示并附带数量和辅助功能说明。
- 菜单栏快速查看待人工审核的摄影机卡。
- 在菜单栏批准建议卷名。
- 在菜单栏手动指派机位、卷号、复用次数和素材后缀。
- 菜单栏自动重命名开关。
- 菜单栏批量批准高置信度卡片。
- 主窗口和菜单栏共用同一套卷名规则、UUID 复核、强制卸载、重挂载和审计记录流程。
- 侧边栏和“关于”窗口新增“检查更新”按钮；启动探测到 GitHub Release 新版本后，按钮显示目标版本，点击后由 Sparkle 展示更新内容并要求确认安装。
- 补充 Sony `M4ROOT` 与 `XDROOT`、MP4 与 MXF 结构识别；兼容部分 CFexpress Type A 读卡器缺失 Foundation 可移除标记的情况。
- 同时挂载的两张卡即使具有重复 Volume UUID，也会通过 BSD 节点和首末素材身份保持独立，避免审核队列互相覆盖。
- 修复 macOS 将第二张同名卡挂载为 `/Volumes/Untitled 1` 时无法自动识别的问题；软件现在使用 `diskutil` 返回的真实卷标。
- 自动重命名改为严格串行队列。两张卡同时完成扫描时会逐张执行，不再因第一张处于重挂载流程而遗漏第二张。
- UUID 相同但首末素材不同的卡允许分别自动处理；UUID 和首末素材完全相同的疑似克隆卡会禁止自动及批量批准。
- 默认后台运行，加入本地通知、卡片忽略/恢复、菜单栏规则切换，以及 720/900/1180 逻辑点响应式主窗口。
- 增加不依赖命令行的中英双语安装与故障排除指南，说明 macOS 14 最低版本、无需额外运行库、可选 exiftool、可移动卷宗权限、未知开发者和损坏提示的安全处理方式。
- DIT Printer 仍为独立项目，Renamer 只保留只读审计数据接口。

分发说明：

- 构建使用 ad-hoc 签名，未进行 Apple notarization。
- 首次启动可能需要在“系统设置 > 隐私与安全性”中允许打开。
- 批量批准会逐张执行，任意一张失败后停止后续操作。
- 菜单栏自动重命名只处理高置信度并通过全部安全规则的卡片。
- 请使用可丢弃测试卡验证现场设备和 Silverstack 的实际行为，不要直接用于生产素材。
- 本版本不复制素材、不执行传输校验、不擦除存储卡。
- 发布前已使用两份克隆 exFAT 镜像模拟同 UUID、同卷名的双读卡器场景，并通过真实 `diskutil` 重命名、强制卸载、重挂载和最终复核；真实读卡器与 Silverstack 仍建议先用可丢弃测试卡验收。

## English

DIT Renamer 1.2.0 is the stable background-first release, with the main operator workflow available directly from the menu bar.

Included in this release:

- App, sidebar, and menu-bar icons were aligned with Apple HIG. The App icon retains the `A247` brand mnemonic, while interface icons use SF Symbols available on macOS 14.
- The menu bar uses a lightweight card-status treatment: an outline when idle, and an emphasized symbol with a count and accessibility description when review is required.
- A menu-bar view for camera cards awaiting operator review.
- Approval of suggested volume names from the menu bar.
- Manual assignment of camera ID, roll number, reuse count, and media suffix.
- A menu-bar auto-rename switch.
- Batch approval for high-confidence cards.
- One shared path for volume-name rules, UUID revalidation, forced remount, and audit history in both the main window and menu bar.
- Check-for-updates buttons were added to the sidebar and About window. When the launch probe finds a newer GitHub Release, the button shows the target version; Sparkle then presents release notes and requires confirmation before installation.
- Sony `M4ROOT` and `XDROOT`, MP4 and MXF structures are covered, including CFexpress Type A readers that do not expose Foundation's removable-media flag consistently.
- Two simultaneously mounted cards remain independent even when they share a Volume UUID, using the BSD node plus first/last clip identity to prevent approval-queue collisions.
- Fixed automatic detection when macOS mounts the second same-name card at `/Volumes/Untitled 1`; the app now uses the real label reported by `diskutil`.
- Automatic renames now use a strictly sequential queue, so a second card is not skipped while the first card is being remounted.
- Cards sharing a UUID remain auto-eligible when first/last clips differ. Exact UUID and clip-identity duplicates require operator review and cannot be batch-approved.
- Added background-first operation, local notifications, ignore/restore controls, menu-bar rule switches, and responsive 720/900/1180-point main-window layouts.
- Added a bilingual GUI-only installation and troubleshooting guide covering the macOS 14 minimum, bundled runtime requirements, optional exiftool, removable-volume permissions, unidentified-developer warnings, and damaged-download recovery.
- DIT Printer remains a separate project. Renamer keeps only its read-only audit-data interface.

Distribution notes:

- This package is ad-hoc signed and is not notarized by Apple.
- macOS may require a one-time approval in System Settings > Privacy & Security.
- Batch approval runs sequentially and stops after the first failure.
- Menu-bar auto-rename processes only high-confidence cards that pass every safety rule.
- Validate the workflow with a disposable test card and the installed Silverstack version before using production media.
- This version does not copy clips, verify transfers, or erase cards.
- Release validation used two cloned exFAT images to simulate same-name, same-UUID cards on separate reader nodes and exercised the real `diskutil` rename, force-unmount, remount, and final verification path. A disposable-card check with the actual readers and Silverstack remains recommended.

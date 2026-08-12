# DIT Renamer 1.2.0 Test

## 中文

这是 DIT Renamer 1.2 的受控测试构建，不是正式稳定发布版本。

本测试版本新增：

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
- DIT Printer 仍为独立项目，Renamer 只保留只读审计数据接口。

测试限制：

- 构建使用 ad-hoc 签名，未进行 Apple notarization。
- 首次启动可能需要在“系统设置 > 隐私与安全性”中允许打开。
- 批量批准会逐张执行，任意一张失败后停止后续操作。
- 菜单栏自动重命名只处理高置信度并通过全部安全规则的卡片。
- 请使用可丢弃测试卡验证现场设备和 Silverstack 的实际行为，不要直接用于生产素材。
- 本版本不复制素材、不执行传输校验、不擦除存储卡。

## English

This is a controlled DIT Renamer 1.2 Test build, not a stable production release.

Included in this test:

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
- DIT Printer remains a separate project. Renamer keeps only its read-only audit-data interface.

Test limitations:

- This package is ad-hoc signed and is not notarized by Apple.
- macOS may require a one-time approval in System Settings > Privacy & Security.
- Batch approval runs sequentially and stops after the first failure.
- Menu-bar auto-rename processes only high-confidence cards that pass every safety rule.
- Validate the workflow with a disposable test card and the installed Silverstack version before using production media.
- This version does not copy clips, verify transfers, or erase cards.

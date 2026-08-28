# DIT Renamer 1.3.0

## 中文

1.3.0 将经过 Test 验证的菜单栏后台工作流整理为正式发布，并修复双卡自动命名和离线待办问题。

- 菜单栏待办只显示当前仍挂载、确实需要人工处理的卡片。自动处理、主界面已批准、正在执行或已经拔出的卡不会残留在待办中；失败项目会重新出现。
- 两张高置信度卡同时得到 `A001` 等相同建议名时，自动队列会在执行前预留 `A001`、`A001_1`、`A001_2`，并逐张完成重命名、强制卸载和重挂载。
- 隐藏卷在重命名或重挂载后即使挂载路径变化，也不会重新出现在菜单栏“卡片”。
- 支持自动挂载卷名为 `DJI Mavic4`、`Osmo360` 或 `Osmo Action` 的外置 USB 直连设备；菜单栏“规则”中可关闭该功能。
- DJI 自动挂载继续执行设备身份复核、三次有界重试和用户主动卸载保护；关闭开关时不会查询磁盘或发出挂载命令。
- 保留 Sony FX3/FX6、ARRI/Codex、Sidecar/XML、可选 ExifTool、ParaShoot 审计、双卡同 UUID 隔离、11 字符卷名上限及严格串行重挂载功能。

分发说明：Universal App，原生支持 Apple Silicon 与 Intel Mac，最低 macOS 14。发布包使用 ad-hoc 签名且未进行 Apple notarization，首次启动请遵循 README 的图形界面安装说明。

## English

DIT Renamer 1.3.0 promotes the Test-validated background menu-bar workflow to a stable release and fixes duplicate automatic names and offline Review items.

- Review now contains only currently mounted cards that genuinely require operator action. Automatically handled, main-window approved, in-progress, and physically removed cards do not remain as tasks; failures return for review.
- When two high-confidence cards share a suggestion such as `A001`, the automatic queue reserves `A001`, `A001_1`, and `A001_2` before sequential rename, force-unmount, and remount operations.
- An ignored volume stays out of menu-bar Cards even if rename/remount changes its mount path.
- External USB devices named `DJI Mavic4`, `Osmo360`, or `Osmo Action` can be mounted automatically. The feature is available as a switch in menu-bar Rules.
- DJI auto-mount retains identity revalidation, three bounded retries, and explicit-unmount protection. Disabling it prevents disk inventory and mount commands.
- Sony FX3/FX6, ARRI/Codex, sidecar/XML, optional ExifTool, ParaShoot audit, same-UUID dual-card isolation, the 11-character name limit, and strictly sequential remount behavior remain intact.

Distribution note: Universal App with native Apple Silicon and Intel support; macOS 14 or later is required. The package is ad-hoc signed and not Apple-notarized. Follow the GUI-only installation steps in the README for first launch.

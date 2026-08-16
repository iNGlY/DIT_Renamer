# DIT Renamer 1.2.2

## 中文

1.2.2 是针对菜单栏卡片列表的紧急热补丁。

- 修复在主界面手动忽略卷后，该卷仍显示在菜单栏“卡片”列表中的问题。
- 主界面和菜单栏现在共用同一套忽略路径过滤。
- 菜单栏直接观察忽略状态；从主界面或菜单栏点击“忽略”后，卡片都会立即隐藏。
- 被忽略卷仍可在主界面的“已忽略”列表中恢复。
- 摄影机识别、审批队列、自动重命名、强制重挂载、审计、Sidecar/XML 和 ExifTool 功能未改变。

分发说明：Universal App，支持 Apple Silicon 与 Intel Mac，最低 macOS 14。发布包使用 ad-hoc 签名且未进行 Apple notarization，首次启动请遵循 README 的图形界面安装说明。

## English

DIT Renamer 1.2.2 is an urgent hotfix for the menu-bar card list.

- Fixed volumes ignored from the main window remaining visible in the menu-bar Cards list.
- The main window and menu bar now use the same ignored-path filter.
- The menu bar observes ignored-volume state directly, so a card disappears immediately when ignored from either surface.
- Ignored volumes remain recoverable from the main window's Ignored list.
- Camera detection, approval queues, automatic rename, forced remount, audit, sidecar/XML, and ExifTool behavior are unchanged.

Distribution note: Universal App for Apple Silicon and Intel Macs; macOS 14 or later is required. The package is ad-hoc signed and not Apple-notarized. Follow the GUI-only installation steps in the README for first launch.

# DIT Renamer 1.3.1

## 中文

1.3.1 修复 Sony FX3 使用机内 `Title + Date` 自定义文件名时无法进入正确重命名流程的问题。

- 支持 `B23_FX3A_20260827_0001.MP4`、`B23_FX3B_20260827_0002.mp4` 等格式，并正确提取 A/B 机位线索。
- `B23_FX3A/B` 仍被视为一个完整的用户自定义 Title；具体机型只由 `M4ROOT` 和 Sony 原生 XML 确认。
- 末尾四位数是电影文件号，不会被当作卡卷 Reel。首次需要操作员设置起始卷号，后续同一 Title 从成功审计历史自动递增。
- 多张同一 Title 卡同时插入时，会预留连续卷号；已成功重命名并重挂载的原卡不会进入下一卷待办。
- 开启代理录制时使用 `M4ROOT/CLIP` 主素材建立卡片指纹，`M4ROOT/SUB` 代理文件不会阻断识别。
- 保持 1.3.0 的菜单栏待办、DJI 自动挂载、双卡串行重挂载、ARRI/Codex、Sidecar/XML、ParaShoot 审计和在线更新功能。

分发说明：Universal App，原生支持 Apple Silicon 与 Intel Mac，最低 macOS 14。发布包使用 ad-hoc 签名且未进行 Apple notarization，首次启动请遵循 README 的图形界面安装说明。

## English

DIT Renamer 1.3.1 fixes the Sony FX3 workflow when the camera records in-camera `Title + Date` custom filenames.

- Supports names such as `B23_FX3A_20260827_0001.MP4` and `B23_FX3B_20260827_0002.mp4`, including the A/B camera-position hint.
- `B23_FX3A/B` remains one user-defined Title. Exact model identification still requires `M4ROOT` plus Sony camera-native XML.
- The final four digits are the movie file counter, not the card reel. The operator sets the first roll; later cards with the same Title increment from successful audit history.
- Simultaneous cards with the same Title reserve consecutive rolls, and a successfully renamed/remounted card is not mistaken for the next reel.
- With proxy recording enabled, card identity uses primary `M4ROOT/CLIP` media and is not blocked by `M4ROOT/SUB` proxy files.
- Preserves the 1.3.0 menu-bar Review workflow, DJI auto-mount, sequential dual-card remounting, ARRI/Codex, sidecar/XML, ParaShoot audit, and online updating.

Distribution note: Universal App with native Apple Silicon and Intel support; macOS 14 or later is required. The package is ad-hoc signed and not Apple-notarized. Follow the GUI-only installation steps in the README for first launch.

# DIT Renamer 1.3.2

## 中文

修复摄影机 SD 卡插入 MacBook 内置读卡器后，软件不显示卡片的问题。

- 正确区分内置读卡器与内部系统磁盘。使用 Secure Digital 协议、可移除且可弹出的 SD 卡不再因 `Internal=true` 被直接过滤；标记为系统内部介质的卷仍会排除。
- Sony FX6 的 `PRIVATE/XDROOT/Clip` MXF/XML 素材可进入现有扫描流程。识别机型与生成卷名是两件事：自定义素材名未提供可靠机位、卷号时，仍需手动指定。
- 保留系统卷、磁盘镜像和网络卷过滤，以及现有自动重命名、双卡串行重挂载、菜单栏审批和审计功能。本次不调整扫描上限。

支持 macOS 14 及以上，原生支持 Apple Silicon 和 Intel。无需额外运行库。发布包使用 ad-hoc 签名，未经 Apple 公证；首次安装请按 README 操作。已有用户可通过应用内检查更新安装。

## English

Fixes camera SD cards not appearing when inserted into a MacBook's built-in card reader.

- Distinguishes a built-in reader from an internal system disk. Removable, ejectable cards using the Secure Digital protocol are no longer rejected solely because macOS reports `Internal=true`. Volumes marked as OS-internal media remain excluded.
- Sony FX6 MXF/XML media under `PRIVATE/XDROOT/Clip` can reach the existing scanner. Model detection does not guarantee a suggested volume name: custom clip names without reliable camera and reel information still require manual assignment.
- Preserves system-volume, disk-image, and network-volume filtering, automatic renaming, sequential dual-card remounting, menu-bar approval, and audit features. Scan limits are unchanged.

Requires macOS 14 or later; runs natively on Apple Silicon and Intel without additional runtimes. The package is ad-hoc signed and not Apple-notarized. Follow the README for first installation, or use Check for Updates in the app.

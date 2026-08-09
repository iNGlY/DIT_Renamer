# DIT Renamer 1.1

DIT Renamer 1.1 是面向 macOS 14+ 现场 DIT 工作流的原生 Swift 应用，用于在素材拷贝开始前识别可移除摄影机媒体、生成并人工确认卷名建议，以及记录重命名审计信息。

## 主要更新

- 提供 Apple Silicon 与 Intel Mac 通用二进制。
- 重命名前复核挂载路径、BSD 节点、Volume UUID 和可用的 Media UUID。
- 重命名成功后强制卸载并重挂载同一分区，缓解 Silverstack 对同名卡的识别冲突。
- 支持手动选择是否保留检测到的媒体 suffix，并执行 FAT、MS-DOS 与 exFAT 的 11 字符卷名限制。
- Apple Disk Image Media、网络卷和系统虚拟卷硬过滤。
- Sony XML/XMP 优先型号识别；可选单文件 exiftool fallback。
- 只读解析 ParaShoot 日志，并按应用当前语言导出中文或英文 PDF。
- `missingFiles: 0` 定义为校验通过；高置信度关联明细由用户选择是否输出。
- 提供只读 Renamer 审计接口给独立的 DIT Printer；Printer 不包含在 1.1 应用包中。

## 预发布限制

本次 GitHub 资产仅使用 ad-hoc 签名，**没有 Apple Developer ID 签名或 notarization 票据**。macOS Gatekeeper 可能阻止直接启动，因此本版本标记为 Pre-release，不是“即开即用”的正式稳定分发版本。

首次运行如被系统阻止，只应使用 macOS“系统设置 > 隐私与安全性”中可见的“仍要打开”流程。本项目不提供 `sudo xattr`、隔离属性清除脚本或自动绕过 Gatekeeper 的工具。

## 现场安全

应用会执行卷重命名以及强制卸载、重挂载。使用前必须停止 Silverstack、Finder 或其他正在访问目标卡的任务，并先在可丢弃测试卡上验证实际设备和现场工作流。DIT Renamer 不复制素材、不执行传输 checksum 校验，也不擦除卡片。

下载后请使用随 Release 提供的 `SHA256SUMS.txt` 核对 DMG 或 ZIP。

---

DIT Renamer 1.1 is a native Swift application for macOS 14+ on-set DIT workflows. This prerelease contains a universal Apple Silicon and Intel build, safer volume identity checks, forced remount after rename, camera-media naming safeguards, Sony metadata detection, and localized read-only ParaShoot audit reports.

The attached assets are ad-hoc signed and **not Apple-notarized**. Gatekeeper may block direct launch, so this build is published as a prerelease. It does not include scripts that clear quarantine attributes or bypass Gatekeeper automatically.

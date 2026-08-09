# DIT Renamer 1.1.1

DIT Renamer 1.1.1 是面向 macOS 14+ 现场 DIT 工作流的原生 Swift 应用，用于在素材拷贝开始前识别可移除摄影机媒体、生成并人工确认卷名建议，以及记录重命名审计信息。本版本加入了基于 Sparkle 的在线更新支持。

## 主要更新

- 提供 Apple Silicon 与 Intel Mac 通用二进制。
- 重命名前复核挂载路径、BSD 节点、Volume UUID 和可用的 Media UUID。
- 重命名成功后自动强制卸载并重挂载同一分区，缓解 Silverstack 对同名卡的识别冲突。
- 支持手动选择是否保留检测到的媒体 suffix，并执行 FAT、MS-DOS 与 exFAT 的 11 字符卷名限制。
- Apple Disk Image Media、网络卷和系统虚拟卷硬过滤。
- Sony XML/XMP 优先型号识别；可选单文件 exiftool fallback。
- 只读解析 ParaShoot 日志，并按应用当前语言导出中文或英文 PDF。
- `missingFiles: 0` 定义为校验通过；高置信度关联明细由用户选择是否输出。
- 提供只读 Renamer 审计数据接口给独立的 DIT Printer。
- 启动时按节流规则检查更新，点击更新后自动替换原安装路径并重启。

## 分发限制

本次资产仅使用 ad-hoc 签名，**没有 Apple Developer ID 签名或 notarization 票据**。macOS Gatekeeper 可能阻止直接启动，因此本版本不应视为“即开即用”的正式签名分发版本。

首次运行如被系统阻止，只应使用 macOS“系统设置 > 隐私与安全性”中可见的“仍要打开”流程。本项目不提供 `sudo xattr`、隔离属性清除脚本或自动绕过 Gatekeeper 的工具。

首次安装需要将 `DIT Renamer.app` 放入 `/Applications` 或 `~/Applications`。之后的 Sparkle 更新在原路径替换整个应用，用户确认后只需重新启动，不需要再次拖拽 App。Sparkle EdDSA 用于验证更新归档完整性，但不能消除 ad-hoc 构建的 Gatekeeper 限制。

## 现场安全

应用会执行卷重命名以及强制卸载、重挂载。使用前必须停止 Silverstack、Finder 或其他正在访问目标卡的任务，并先在可丢弃测试卡上验证实际设备和现场工作流。DIT Renamer 不复制素材、不执行传输 checksum 校验，也不擦除卡片。

## 许可证

Copyright 2026 DIT247。项目采用 Apache License 2.0，商业使用和再分发必须保留许可证、版权声明及 `NOTICE` 中的 DIT247 原始发布者信息。

---

DIT Renamer 1.1.1 is a native Swift application for macOS 14+ on-set DIT workflows. It provides camera-media naming safeguards, forced remount after rename, Sony metadata detection, localized read-only ParaShoot audit reports, and Sparkle-based in-app updates.

The attached assets are ad-hoc signed and **not Apple-notarized**. Gatekeeper may block direct launch. Sparkle verifies update archives with EdDSA, but it does not replace Developer ID signing or notarization. The first installation requires placing `DIT Renamer.app` in `/Applications` or `~/Applications`; later updates replace the app in place and restart it after user confirmation.

Licensed under Apache License 2.0. Commercial redistribution must retain the license, copyright notices, and the DIT247 attribution contained in `NOTICE`.

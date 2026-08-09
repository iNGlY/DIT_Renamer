# DIT Renamer 1.1 GitHub 发布说明与需求

## 发布定位

- Git 标签：`v1.1.0`
- GitHub Release 标题：`DIT Renamer 1.1`
- 当前版本标记为 **Latest Release**，但未公证状态必须在资产名称、安装说明和 Release Notes 中明确展示。
- 资产名称必须保留 `adhoc-unnotarized`，不得描述为已签名、公证、staple 或 Gatekeeper 验证通过。
- 取得 Developer ID 并完成 notarization 后，使用相同源码重新构建正式资产，再创建或替换稳定发布。

## 本次功能

- 原生 Swift、SwiftUI 与 AppKit 实现的 macOS 14+ 通用应用，支持 Apple Silicon 与 Intel Mac。
- 在开始素材拷贝前识别可移除摄影机媒体并提供卷名建议。
- 重命名前复核挂载路径、BSD 节点、Volume UUID 和可用的 Media UUID。
- 重命名成功后强制卸载并重挂载同一分区，缓解 Silverstack 对同名卡的识别冲突。
- 支持手动选择是否保留检测到的媒体 suffix，并执行 FAT、MS-DOS 与 exFAT 的 11 字符卷名限制。
- Apple Disk Image Media、网络卷和系统虚拟卷硬过滤。
- Sony XML/XMP 优先型号识别；可选单文件 exiftool fallback。
- 只读解析 ParaShoot 日志，按应用当前语言导出中文或英文 PDF；`missingFiles: 0` 定义为校验通过，高置信度关联明细由用户选择是否输出。
- 提供只读 Renamer 审计接口给独立的 DIT Printer；Printer 不包含在 1.1 应用包中。

## 资产

- `dit_renamer_Release_1.1-adhoc-unnotarized.dmg`
- `dit_renamer_Release_1.1-adhoc-unnotarized.zip`
- `SHA256SUMS.txt`
- `LICENSE`
- `NOTICE`
- GitHub 自动生成的 tag source archives；本地 `Release/Source Code` 用于核对构建来源。

发布脚本会验证 ZIP、DMG 和校验和文件存在，并核对 App 二进制同时包含 `arm64` 与 `x86_64`。

## 安装与安全说明

此 GitHub 预发布包仅使用 ad-hoc 签名，没有 Apple notarization 票据。macOS Gatekeeper 可能阻止直接启动，因此它不是“即开即用”的正式分发版本。首次运行如被系统阻止，只应使用 macOS“系统设置 > 隐私与安全性”中可见的“仍要打开”流程。项目不提供 `sudo xattr`、隔离属性清除脚本或自动绕过 Gatekeeper 的工具。

应用会执行卷重命名以及强制卸载、重挂载。使用前必须停止 Silverstack、Finder 或其他正在访问目标卡的任务，并先在可丢弃测试卡上验证实际设备和现场工作流。DIT Renamer 不复制素材、不执行传输 checksum 校验，也不擦除卡片。

## GitHub 仓库要求

- 明确仓库的 `owner/name` 和公开性；首次创建公开仓库属于外部发布动作，需要发布者确认。
- 本机 `gh auth status` 必须显示已登录并具有仓库写入权限。
- 本地仓库必须配置 `origin`，且发布提交必须已推送。
- 发布前工作区必须干净，构建产物必须来自当前 `HEAD`。
- 建议启用受保护的 `main` 分支、至少一项双架构构建检查，以及 GitHub Release 资产校验。
- 不得提交 Apple ID、app-specific password、notarytool profile、证书私钥或任何 GitHub token。

## 发布命令

```bash
gh auth login
git remote add origin https://github.com/OWNER/DIT_Renamer.git
DIT_RENAMER_RELEASE_MODE=adhoc ./scripts/build_swift_app.sh
./scripts/publish_github_release.sh
```

发布脚本默认创建 **Latest Release**。它不会创建 GitHub 仓库，也不会决定仓库公开性。

## 后续正式版要求

正式稳定发布必须恢复默认构建模式，并满足：

1. 可用的 `Developer ID Application` 证书。
2. 可验证的 `notarytool` 钥匙串 profile。
3. App 与 DMG 分别完成签名、notarization 和 staple。
4. 本机 `spctl` 对 App 与 DMG 均通过。
5. 重新生成 SHA-256 校验和，并在 Release 说明中移除 ad-hoc 警告。

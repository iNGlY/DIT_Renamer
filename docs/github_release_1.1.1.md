# DIT Renamer 1.1.1 GitHub 发布要求

## 发布定位

- Git 标签：`v1.1.1`
- GitHub Release 标题：`DIT Renamer 1.1.1`
- 当前构建是 universal（arm64 + x86_64）的 Swift 应用，包含 Sparkle 2.9.5 在线更新支持。
- 没有 Developer ID 时，只能发布明确标注 `adhoc-unnotarized` 的测试/预发布资产；不得描述为已公证或 Gatekeeper 验证通过。
- 发布前必须先上传 Release 资产，再将生成后的 `appcast.xml` 发布到 GitHub Pages，避免客户端访问不存在的更新归档。

## 本版本内容

- 原生 Swift、SwiftUI 与 AppKit 实现的 macOS 14+ 通用应用。
- 在素材拷贝开始前识别可移除摄影机媒体并提供卷名建议。
- 重命名前复核挂载路径、BSD 节点、Volume UUID 和可用的 Media UUID。
- 重命名成功后自动强制卸载并重挂载同一分区，缓解 Silverstack 对同名卡的识别冲突。
- 支持手动选择是否保留检测到的媒体 suffix，并执行 FAT、MS-DOS 与 exFAT 的 11 字符卷名限制。
- Apple Disk Image Media、网络卷和系统虚拟卷硬过滤。
- Sony XML/XMP 优先型号识别；可选单文件 exiftool fallback。
- 只读解析 ParaShoot 日志，按应用当前语言导出中文或英文 PDF；`missingFiles: 0` 定义为校验通过，高置信度关联明细由用户选择是否输出。
- 提供只读 Renamer 审计接口给独立的 DIT Printer；Printer 不包含在 1.1.1 应用包中。
- 启动后按 24 小时节流规则检查更新；用户确认后由 Sparkle 在原安装路径替换并重启应用。

## 资产与验证

推荐资产名：

- `dit_renamer_Release_1.1.1-adhoc-unnotarized.dmg`
- `dit_renamer_Release_1.1.1-adhoc-unnotarized.zip`
- `SHA256SUMS.txt`
- `LICENSE`
- `NOTICE`

发布脚本必须验证 ZIP、DMG、SHA-256、当前提交来源和 App 的 `arm64`/`x86_64` 架构。Sparkle 更新归档使用 ZIP；同一版本不要同时把 DMG 和 ZIP 写入 appcast，否则会产生重复更新条目。

生成更新 feed：

```bash
DIT_RENAMER_VERSION=1.1.1 scripts/generate_appcast.sh Release
```

EdDSA 私钥只能来自发布者本机钥匙串或受保护的外部密钥文件，不得提交仓库。`docs/appcast.xml` 在 GitHub Release 资产尚未公开前保持空 feed；资产可下载后再提交包含签名 enclosure 的版本。

## 安装与安全说明

此版本没有 Developer ID 签名和 Apple notarization 票据。首次安装仍需用户将 `DIT Renamer.app` 放入 `/Applications` 或 `~/Applications`，并在 macOS 阻止时通过“系统设置 > 隐私与安全性”选择“仍要打开”。后续在线更新由 Sparkle 在原路径完成替换，用户只需点击重新启动，不需要再次拖拽 App。

Sparkle EdDSA 只验证更新归档来源和完整性，不能替代 Developer ID、notarization 或 Gatekeeper 信任。本项目不提供 `sudo xattr`、隔离属性清除脚本或自动绕过 Gatekeeper 的工具。

应用会执行卷重命名以及强制卸载、重挂载。使用前必须停止 Silverstack、Finder 或其他正在访问目标卡的任务，并先在可丢弃测试卡上验证实际设备和现场工作流。DIT Renamer 不复制素材、不执行传输 checksum 校验，也不擦除卡片。

## 发布前检查

- `gh auth status` 已登录，并且 `origin` 指向 `https://github.com/iNGlY/DIT_Renamer.git`。
- 发布提交已经推送，工作区干净，Release 元数据中的 commit 与 `HEAD` 一致。
- `codesign --verify --deep --strict`、`lipo -verify_arch arm64 x86_64`、SHA-256 和 appcast XML 校验通过。
- GitHub Pages 已配置为发布 `docs/`，并确认 `https://ingly.github.io/DIT_Renamer/appcast.xml` 可访问。
- 真实更新链路至少在 Apple Silicon、Intel、`/Applications` 和普通用户权限下验证；开发阶段不可用真实摄影机卡执行卸载或重挂载测试。

## 发布命令

```bash
DIT_RENAMER_RELEASE_MODE=adhoc scripts/build_swift_app.sh
scripts/generate_appcast.sh Release
scripts/publish_github_release.sh
```

无 Developer ID 时请将 GitHub Release 标为预发布，直到获得 Developer ID、完成 notarization、staple 和 Gatekeeper 实机验证。


# DIT Renamer macOS 在线更新调研

调研日期：2026-08-10
范围：Sparkle 2、Apple Developer ID / notarization、GitHub Releases / Pages / Actions。本文只提出方案，不包含应用代码修改。

## 结论

建议使用 **Sparkle 2.9.5**，不要自行实现下载、验签、替换应用和重启流程。将 Sparkle 包装在一个小型 `UpdateController` 中，由它独占 `SPUStandardUpdaterController`；`App.swift`、菜单和设置页只调用“检查更新”及读写自动检查选项。

截至调研日，Sparkle 官方最新稳定版是 **2.9.5**（2026-08-02 发布，非 prerelease），且该版本包含 2.9 系列安全修复。官方当前 2.x `Package.swift` 将 SwiftPM 最低平台设为 **macOS 12**；下载的 2.9.5 二进制 framework 及辅助组件的 `LSMinimumSystemVersion` 则为 **macOS 10.13**。DIT Renamer 当前最低系统是 macOS 14，因此无论按包解析还是运行时要求，引入 2.9.5 都不会提高本项目现有系统要求。

- 最新发布：[Sparkle 2.9.5](https://github.com/sparkle-project/Sparkle/releases/tag/2.9.5)
- 官方 2.x 包清单：[Package.swift](https://github.com/sparkle-project/Sparkle/blob/2.x/Package.swift)

当前 GitHub `v1.1.0` 应用没有内置 Sparkle，不能让已安装的 1.1.0 自行获得更新器。第一个含 Sparkle 的版本仍需用户手动下载安装；只有从这个“引导版本”开始，后续版本才可在线更新。

## SwiftUI 与当前构建方式

Sparkle 官方 SwiftUI 示例在 `App` 生命周期内长期持有：

```swift
SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
)
```

菜单的“检查更新…”调用 `updater.checkForUpdates`，并观察 `updater.canCheckForUpdates` 来控制禁用状态。设置页直接读写 `SPUUpdater.automaticallyChecksForUpdates` 和可选的 `automaticallyDownloadsUpdates`；这些属性已有 `NSUserDefaults` 持久化，不应再维护第二份偏好值，也不应在每次启动时强行覆盖用户选择。

来源：

- [Sparkle：Programmatic setup / SwiftUI](https://sparkle-project.org/documentation/programmatic-setup/)
- [Sparkle：SwiftUI settings UI](https://sparkle-project.org/documentation/preferences-ui/)
- [SPUStandardUpdaterController API](https://sparkle-project.org/documentation/api-reference/Classes/SPUStandardUpdaterController.html)

建议为本项目提供这一层边界：

```text
UpdateController
  checkForUpdates()
  canCheckForUpdates
  automaticallyChecksForUpdates
  automaticallyDownloadsUpdates（可选）
```

Sparkle 的 feed 解析、EdDSA 验签、下载、解压、替换、授权和重启不应泄漏到视图层。

本项目由脚本直接调用 `swiftc`，不是 Xcode / Swift Package 工程，因此可采用 Sparkle 官方的“手动集成”路径：

1. 固定下载 2.9.5 二进制发行包并校验 SHA-256，不在每次构建时追踪 `latest`。
2. 将 `Sparkle.framework` 原样复制到 `DIT Renamer.app/Contents/Frameworks/`，必须保留符号链接和可执行权限。
3. 编译、链接时增加 framework 搜索路径、`-framework Sparkle` 和指向 `Contents/Frameworks` 的运行时 rpath。
4. 继续构建 arm64 + x86_64；实测 2.9.5 的 `Sparkle` 与 `Autoupdate` 可执行文件均为 arm64/x86_64 universal binary。
5. 在生成的 `Info.plist` 中加入 `SUFeedURL`、`SUPublicEDKey`；自动检查的默认行为可由 `SUEnableAutomaticChecks` 配置。

当前脚本将版本号和发布模式写进 `.app` 名称，例如 `dit_renamer_Release_1.1-adhoc-unnotarized.app`。Sparkle 官方要求更新归档内的应用与被替换应用保持同名，因此首个集成版应固定内部 bundle 名为 `DIT Renamer.app`；版本号与发布模式只出现在 ZIP/DMG 资产名及 `Info.plist`。这也意味着现有 1.1.0 用户必须手动安装一次采用稳定名称的引导版本。

非 Xcode 集成、rpath、复制位置及必要 `Info.plist` 项均见：[Sparkle basic/programmatic setup](https://sparkle-project.org/documentation/)。

## Appcast 与 GitHub 托管

Sparkle 使用 appcast（扩展 RSS XML）发现更新。建议：

- `SUFeedURL` 指向 GitHub Pages 的固定 HTTPS 地址，例如 `https://ingly.github.io/DIT_Renamer/appcast.xml`。
- appcast 中每个 `enclosure` 指向该版本不可变的 GitHub Release 资产，例如 `https://github.com/iNGlY/DIT_Renamer/releases/download/v1.2.0/DIT_Renamer-1.2.0.zip`。
- 不建议历史 appcast 项使用 `/releases/latest/download/...`，因为该 URL 会随 Latest Release 改变；GitHub 虽官方支持该形式，但历史项应绑定具体 tag 和唯一资产名。
- GitHub Pages 是官方静态站点托管服务，适合公开、稳定地提供 `appcast.xml`；发布资产仍由 GitHub Releases 承载。

来源：

- [Sparkle：发布 appcast](https://sparkle-project.org/documentation/#5-publish-your-appcast)
- [Sparkle：Publishing an update](https://sparkle-project.org/documentation/publishing/)
- [GitHub Pages：静态站点托管](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages)
- [GitHub：latest release 与 latest asset URL](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases)

`CFBundleVersion` 必须单调递增，Sparkle 用它判断新旧；面向用户的版本写入 `CFBundleShortVersionString`。建议从下一版起明确分离，例如：

```text
CFBundleShortVersionString = 1.2.0
CFBundleVersion            = 1200（或 CI 单调递增整数）
```

来源：[Apple CFBundleVersion](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion)；[Sparkle appcast setup](https://sparkle-project.org/documentation/#5-publish-your-appcast)。

## EdDSA 与 Apple 签名不是同一层

| 机制 | 验证对象 | 解决的问题 | 不能替代 |
| --- | --- | --- | --- |
| Sparkle EdDSA (ed25519) | ZIP/DMG/delta 更新归档 | 更新来自持有私钥的发布者，归档未被篡改 | Developer ID、Hardened Runtime、Apple notarization、Gatekeeper 信任 |
| Developer ID 代码签名 | `.app` 及嵌套可执行代码 | Gatekeeper 识别发布者并验证代码完整性 | Sparkle appcast/归档签名 |
| Apple notarization + staple | 已签名分发件 | Apple 安全扫描并签发公证票据；staple 将票据附到分发件 | Sparkle 的更新源和归档验签 |

Sparkle 要求发布更新归档使用 EdDSA 签名：首次运行 `generate_keys`，私钥保存在钥匙串或受保护的 CI secret，公钥写入应用的 `SUPublicEDKey`。归档签名由 `generate_appcast` 自动写入 appcast。Sparkle 2.9 还支持可选的签名 feed；若启用 `SURequireSignedFeed`，同时必须启用 `SUVerifyUpdateBeforeExtraction`，且以后修改 appcast 或 release notes 后必须重新签名。

Apple 明确说明：Developer ID 供 Gatekeeper 验证 Mac App Store 外分发者；notary service 扫描 Developer ID 签名软件并签发票据，命令行流程使用 `xcrun notarytool`，票据可用 `xcrun stapler` 附加。

来源：

- [Sparkle security / EdDSA / signed feeds](https://sparkle-project.org/documentation/#3-segue-for-security-concerns)
- [Apple Developer ID](https://developer.apple.com/developer-id/)
- [Apple：Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

因此，当前 ad-hoc、未公证的发行方式即使加入 EdDSA，也不能称为“Gatekeeper 即开即用”或完全无提示更新。若目标是可靠公开分发，Developer ID + Hardened Runtime + notarization + staple 仍是上线前置条件。

## 更新检查行为与性能影响

Sparkle 官方默认行为：

- 未设置 `SUEnableAutomaticChecks` 时，初始关闭自动检查，在**第二次启动**询问用户是否允许。
- 用户允许后，默认每 **86,400 秒（24 小时）**后台检查一次。
- `SUScheduledCheckInterval` 最小为 **1 小时**，避免给服务器造成过量请求。
- 自动下载安装默认关闭（`SUAutomaticallyUpdate = NO`）。手动“检查更新…”不受 24 小时周期限制。
- 不应在应用代码中反复调用 `checkForUpdatesInBackground()`；官方说明这样会干扰 Sparkle 调度器。

来源：[Sparkle customization](https://sparkle-project.org/documentation/customization/)；[Sparkle API expectations](https://sparkle-project.org/documentation/programmatic-setup/#api-expectations)。

对 DIT Renamer 的预计影响很小，但官方没有公布可直接引用的 CPU、内存或启动耗时基准，因此不能给出可靠的毫秒数或内存数值：

- 空闲时没有持续扫描 GitHub 的循环，仅保留调度状态；默认一天一次网络请求。
- appcast 获取和后台检查不应阻塞主界面；网络延迟只影响检查结果返回时间。
- 只有发现更新后才发生大文件下载、解压、验签和替换，主要开销集中在用户更新阶段，不会进入摄影机卡识别/重命名热路径。
- `SPUStandardUpdaterController` 和 framework 动态加载会增加少量启动与常驻内存开销，具体值必须在集成构建上用 Instruments 测量。

可复核的体积数据（2026-08-10 在本机解包 Sparkle 官方 2.9.5 发行资产）：

- 官方完整发行包 `Sparkle-2.9.5.tar.xz`：15,557,500 bytes（GitHub 资产元数据）。
- 官方 SPM ZIP：11,571,026 bytes（GitHub 资产元数据）。
- 解包后的 `Sparkle.framework`：约 3,060 KiB 磁盘占用；其中主 universal binary 为 977,616 bytes，`Autoupdate` 为 726,096 bytes。
- 当前 DIT Renamer 应用约 6.5 MiB；不考虑后续签名差异，嵌入完整 framework 后 bundle 体积粗略增至约 9.5 MiB。单独压缩 framework 实测约 0.98 MiB，因此发布 ZIP 的增量量级约为 1 MiB，而不是完整发行包的 11-16 MiB。

这些数字只能说明发布包/应用体积增量，不能推导运行内存。正式接入后应对“无 Sparkle 基线”和“含 Sparkle 构建”各测 10 次冷启动时间、启动后 60 秒空闲 CPU/内存、手动检查响应时间及更新安装时间。

## 推荐发布流水线

1. **准备一次性密钥**：离线运行 Sparkle `generate_keys`；公钥进入 `Info.plist`，私钥放发布 Mac 钥匙串或受保护的 GitHub Actions secret，绝不提交仓库。
2. **固定依赖**：固定 Sparkle 2.9.5 与官方 SHA-256；更新 Sparkle 时单独审查 release notes，2.9.5 本身含安全修复。
3. **构建 universal app**：复制 framework 并保留 symlink/权限，生成递增版本号，完成 arm64/x86_64 构建。
4. **正式签名**：按由内到外顺序签署 Sparkle 嵌套 helper/framework 和主应用，启用 Hardened Runtime；验证 `codesign`。
5. **公证与 staple**：用 `notarytool` 提交，等待 Accepted，对应用/DMG 执行 `stapler`，再以 `spctl` 在干净实机验证。
6. **生成更新归档**：ZIP/DMG 内应用名称必须与被替换版本一致；归档必须保留 framework 符号链接。若用 ZIP，归档内只放 `.app`。
7. **生成 appcast**：运行 Sparkle `generate_appcast`；它会计算 EdDSA 签名，并可生成 delta。首版建议先不启用 delta，先稳定验证完整包更新。
8. **发布资产**：先将已签名、公证、staple、EdDSA 可验证的版本唯一资产上传到对应 GitHub Release。
9. **最后发布 feed**：资产可下载后再将新 `appcast.xml` 发布到 GitHub Pages，避免客户端看到尚不存在的 enclosure。
10. **验证升级链**：至少实测“上一稳定版 -> 新版”、Intel、Apple Silicon、普通用户权限、`/Applications`、断网、下载中断、GitHub 404、签名错误和回滚阻止。

若坚持“GitHub Release 发布之后才生成 feed”，GitHub Actions 可监听：

```yaml
on:
  release:
    types: [published]
```

GitHub 官方说明 `published` 同时覆盖稳定版和从 draft 发布的 prerelease，因此稳定 feed 任务还应判断 `github.event.release.prerelease == false`。macOS runner 下载刚发布资产，使用 Sparkle `generate_appcast --ed-key-file -` 从 secret 标准输入读取私钥，再部署 Pages。若要生成 delta，CI 还必须取得旧 appcast 和相应历史完整归档。

来源：[GitHub Actions `release` 事件](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#release)；[Sparkle generate_appcast](https://sparkle-project.org/documentation/#5-publish-your-appcast)。

## 针对现场 DIT 的约束

- 更新检查失败不得阻止应用启动、卷扫描或重命名；只记录更新子系统错误。
- 正在执行强制卸载、卷重命名、重挂载或生成审计报告时，不应触发安装/重启；更新可下载，但安装应延迟至事务结束或退出应用。
- 默认保留 Sparkle 的第二次启动授权询问和每日检查，不在每次启动强制联网。
- 第一个 Sparkle 版本上线前必须保留独立测试 appcast，不能拿公开稳定 feed 直接测试高版本构建。
- Appcast 更新应是发布流程最后一步；撤回故障版本时先从 feed 移除，再处理 GitHub Release，但已下载更新仍需通过版本与签名策略处置。

## 版本替换与旧副本清理

“自动删除原版本”不应实现为启动时按名称扫描并直接 `removeItem`。安全实现分为两条路径：

1. **正常在线更新**：固定安装路径和 `.app` 名称，例如 `/Applications/DIT Renamer.app`。Sparkle 在该路径内完成下载包验证、解压、退出旧进程、原子替换和重新启动；应用代码不自行删除正在运行的 bundle。这个过程本身就是旧版本被替换，不需要额外清理器。
2. **1.1.0 到稳定名称的首次迁移**：新版本首次启动后写入一个待验证记录，包含旧版本、目标 `CFBundleVersion`、更新时间和新 bundle 路径。只有当 `Bundle.main` 的 bundle identifier 正确、当前版本达到或超过目标版本、当前路径确实是 `/Applications/DIT Renamer.app`，并且没有正在进行的卡片重命名/强制卸载/重挂载事务时，才开始处理历史副本。

历史副本清理必须满足全部条件：

- 只检查当前应用所在目录，不递归扫描用户主目录、Downloads、DMG 或外接媒体；
- 只匹配明确的旧版本命名模式，并读取候选 `.app` 的 `CFBundleIdentifier`，不能只按文件名判断；
- 不处理当前 bundle、版本相同或更高的副本、正在运行的副本、符号链接、只读卷或不明确的候选项；
- 优先调用 `NSWorkspace`/`FileManager` 的废纸篓接口，让用户可以恢复，而不是永久删除；
- 每个候选项记录路径、bundle identifier、版本、处理结果；发生权限错误或候选项超过一个时停止自动清理并提示用户。

清理动作应安排在新版本成功启动后的下一轮主队列中，不能由 Sparkle 的安装过程额外启动一个未经签名的删除脚本。首次迁移失败不应回退或删除当前新版本，只保留待处理状态，下一次启动再次检查。

为确保“更新后确实是最新版本”，安装前记录目标 build，安装后在启动阶段验证 `CFBundleVersion` 和 bundle identifier；校验失败时保留现状、显示更新失败并提供手动打开固定 Release 页面入口。版本新旧以单调递增的 `CFBundleVersion` 和已签名 appcast 为准，不以 GitHub API 返回的 `latest` 文本或应用文件名为准。Sparkle 同时负责阻止 appcast 中的降级版本。

因此，推荐的用户可见策略是“自动替换当前安装版本，自动将已确认的旧副本移入废纸篓”，而不是不可恢复删除所有旧版本。若未来需要永久删除废纸篓中的副本，必须另设明确的用户确认流程。

## 建议实施顺序

1. 第一阶段：接入 Sparkle 2.9.5、菜单手动检查、设置页自动检查开关、完整 ZIP 更新、独立测试 feed。
2. 第二阶段：Developer ID / notarization / staple 全链路和 GitHub Pages 稳定 feed，上线首个手动安装的“引导版本”。
3. 第三阶段：GitHub Actions 自动生成 appcast、签名 feed、release notes、多版本升级测试。
4. 第四阶段：数据证明完整包过大时再启用 delta 和分阶段发布；DIT Renamer 当前体积不应先为 delta 增加发布复杂度。

## 当前实装状态

本次已在 Swift 1.1.1 工作区实现免费 ad-hoc 更新模式：

- `UpdateController` 持有 `SPUStandardUpdaterController`，启动后按 24 小时间隔执行一次后台检查，并提供菜单手动检查；自动下载和自动安装保持关闭。
- 构建脚本固定下载并校验 Sparkle 2.9.5，嵌入 universal framework，写入 `SUFeedURL`、`SUPublicEDKey`，并按由内到外顺序签署 helper、framework 和 App。
- App 内部名称固定为 `DIT Renamer.app`，版本号独立写入 `CFBundleShortVersionString`/`CFBundleVersion`。
- 重命名事务由共享状态保护，Sparkle 在卷操作期间拒绝继续更新；更新前保存目标 build，重启后验证版本，失败时不清理旧版本。
- 只对 `/Applications` 或 `~/Applications` 下明确匹配 bundle identifier 且低于当前版本的历史版本执行可恢复的废纸篓迁移。
- `scripts/generate_appcast.sh` 选择 ZIP 作为唯一更新载荷并禁用 delta；DMG 仍用于首次安装和人工下载。

当前仓库只包含空的初始 appcast，GitHub Pages 尚未部署真实更新条目。首次可用升级链仍需手动安装带 Sparkle 的 1.1.1 引导版本；之后的 1.1.x 更新可以由 Sparkle 原位替换并重新启动。

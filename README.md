# DIT Renamer 1.1

DIT Renamer 是面向 macOS 现场 DIT 工作流的原生 Swift 应用，用于识别已挂载的可移除摄影机媒体、人工确认或按明确规则生成卷名，并记录可追溯的重命名审计信息。

## 运行边界

- 产品实现为纯 Swift/AppKit/SwiftUI；Python、Web UI 和 PyInstaller 入口已废弃。
- 只处理 macOS 报告为可移除且非内置的已挂载卷。
- 在重命名前复核挂载路径、BSD 分区节点、Volume UUID，并在可用时复核 Media UUID。
- 重命名成功后仅针对已复核的同一 BSD 分区执行强制卸载、重挂载和 UUID/卷名复核；操作前必须停止会持续访问该卷的任务。
- 未完成扫描、未识别媒体、空卡、照片卡、未配置机位或残留旧素材不会进入自动重命名队列。
- 所有自动命名都应视为建议；厂商目录结构和机型证据不足时必须人工确认。

## 项目结构

```text
DIT_Renamer/
├── src_swift/             # Swift 源码
│   ├── Models/            # 语言和审计持久化
│   ├── Views/             # SwiftUI 界面
│   ├── MediaScanner.swift # 媒体目录扫描
│   ├── VolumeMonitor.swift# 可移除卷监控
│   └── RenamerEngine.swift# BSD/UUID 复核与重命名
├── docs/                  # DIT 现场相关说明与研究记录
└── scripts/build_swift_app.sh
```

## 构建

需要 macOS 14 或更高版本，以及 Apple Swift 编译器。构建前建议先运行类型检查：

```bash
swiftc -typecheck -target arm64-apple-macosx14.0 $(find src_swift -name '*.swift' -print)
bash -n scripts/build_swift_app.sh
```

生成 1.1 的 `.app`、`.zip` 和 `.dmg`：

```bash
./scripts/build_swift_app.sh
```

输出只写入项目内的 `build_swift/` 和 `Release/`，这两个目录属于生成物，不是源代码输入。

## 现场提示

重命名是卷级元数据操作。执行前应停止会持续访问该卷的拷贝、校验或媒体管理任务；程序自身不会替现场人员判断 Silverstack、Finder 或其他进程是否仍在使用媒体。拔卡、换卡或设备节点变化后，必须重新选择并扫描卷。

厂商命名规则、媒体结构和同类软件能力的核对结果见 [`docs/research_swift_1.1_vendor_rules.md`](docs/research_swift_1.1_vendor_rules.md)。

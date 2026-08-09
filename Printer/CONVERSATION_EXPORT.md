# DIT Printer 对话整理与需求导出

导出日期：2026-08-10

这份文件把本次对话中的自然语言要求整理为可执行的产品与工程上下文，供
Antigravity IDE 或后续工程师直接接手。它不是 DIT Renamer 的需求变更。

## 一、最终目标

建立一个名为 `DIT Printer` 的独立 macOS 程序。Silverstack 的 Copy Job 完成
后，尤其是 Verify 设置为 `Included in copy job` 时，Silverstack 发送完成
manifest。DIT Printer 接收后创建待打印任务；打印不应等待后续业务处理。

在同一个成功的 Copy + Verify 事件中，打印信号和 ParaShoot 可逆擦除信号可以
并行发出。ParaShoot 擦除只允许由明确配置的 Silverstack 工作流触发，并且必须
指向当前存储卡与至少一个已经由同一 Copy Job 校验过的目标盘。

DIT Printer 必须完全独立维护。不得把 Printer 的 UI、打印机驱动、模板、历史或
ParaShoot 逻辑并入 DIT Renamer，也不得修改 DIT Renamer 的核心代码。

## 二、标签数据要求

每个任务需要支持以下数据：

- Silverstack Bin name，作为素材盘/标签的名称。
- Silverstack 提供的最后一条拷贝素材文件名。
- Silverstack Copy Job 完成时间。
- DIT Printer 实际收到完成信号的时间。
- 完成信号来源，例如 `Silverstack Copy Job (Verify Included)`。
- 操作者手动输入的当前存储卡复用次数。
- 可选的源卷路径和只读 Renamer audit context。

上述字段需要在任务详情、打印预览、可选标签字段和导出历史中保持一致。

## 三、打印机兼容要求

程序不能只绑定 GP-M325F。设置页中需要允许保存多个可复用的打印配置：

1. CUPS PDF：面向大多数 macOS/CUPS 打印机。
2. CUPS Raw command：把原始命令发送给 CUPS 队列。
3. Custom CLI：直接启动绝对路径的 CLI，不经过 shell。

当前命令语言选项：

- TSPL：TSC、GP-M325F 等兼容设备。
- ZPL：Zebra 系列及兼容设备。
- EPL/EPL2：Eltron/Zebra 兼容设备。
- CPCL：Zebra 移动标签打印机常用语言。
- PDF：通用 CUPS 或自定义 CLI 的 PDF 输入。

原始位图当前按 203 dpi 生成，语言命令分别使用 TSPL `BITMAP`、ZPL
`^GFA`、EPL `GW`、CPCL `CG`。机型、固件命令语言、分辨率、标签间隙和切纸
策略必须由现场配置确认。开发阶段只生成命令文件，不连接实际打印机。

Custom CLI 的参数为一行一个参数，必须存在单独的 `{file}` 参数。程序把它替换
为实际生成的文件路径，并使用 `Process` 直接启动可执行文件，不能调用 shell。

## 四、模板与耗材要求

模板必须持久化，并可跨 Silverstack 项目使用。内置建议尺寸：

- 40 x 30 mm：紧凑标签。
- 50 x 30 mm：小型卡盒。
- 60 x 40 mm：日常推荐。
- 72 x 51 mm：信息完整，默认推荐。
- 80 x 50 mm：需要较大字体或更多字段。

自定义模板需要保存宽度、高度、间隙、标题、页脚、备注和启用字段。用户可以
选择是否打印 Bin、最后素材、Copy 完成时间、复用次数、信号来源、接收时间、
源卷路径和自定义备注。已有旧模板必须继续可读，新增字段使用合理默认值。

## 五、历史与审计要求

任务 JSON 是打印历史的来源，存放在：

```text
~/Library/Application Support/DIT Printer/Jobs
```

主窗口应支持导出 CSV 和 JSON。历史至少包含：任务 ID、状态、信号来源、收到
信号时间、Copy 完成时间、Bin、最后素材、复用次数、模板快照、打印配置快照、
命令语言、CUPS 队列或 CLI 结果、实际提交时间和错误信息。

“DIT Printer 收到信号”与“打印机完成物理打印”必须是两个不同概念。UI 和历史
不能混用这两个时间。

## 六、Silverstack 与 ParaShoot 事件约束

推荐的 Lua Post Step 是：

```text
Printer/src/Silverstack/DITPrinterAndParaShootAfterCopyVerify.lua
```

配置要求：

1. Copy Job 的 Verify 设置为 `Included`。
2. Input Files 顺序为 Source card、已校验 Destination 1。
3. 只有 `success=true` 才可发送打印和擦除桥接请求。
4. 打印桥接和擦除桥接从同一成功事件并行启动，Silverstack 不等待二者完成。
5. 源卡必须是 `/Volumes/` 下的外置可移动卷，目标盘必须存在且不能等于源卡。
6. ParaShoot 桥接会在真正请求前执行设备身份和 `is-card` 预检。

中文 Lua 注释只用于人工审阅，不是有效的业务信息，也不能改变任何判断或命令。

## 七、当前实现位置

- `src/DITPrinterApp.swift`：主窗口、任务详情、模板/打印配置设置、预览。
- `src/Shared/PrinterJob.swift`：任务、字段、模板和持久化模型。
- `src/PrintProfileStore.swift`：输出方式、命令语言和配置持久化。
- `src/CUPSPrinter.swift`：PDF、TSPL、ZPL、EPL、CPCL 渲染与提交。
- `src/LabelTemplateStore.swift`：耗材模板持久化。
- `src/PrintHistoryExporter.swift`：CSV/JSON 历史导出。
- `src/DITPrinterBridge.swift`：Silverstack manifest 接收。
- `src/ParaShootEraseBridge.swift`：高风险 ParaShoot 桥接，前端工作不要改它。
- `src/Silverstack/`：Silverstack Lua 脚本。
- `scripts/build_printer.sh`：独立构建入口。

## 八、已完成验证

从 `Printer/` 目录执行：

```bash
bash -n scripts/build_printer.sh
./scripts/build_printer.sh
codesign --verify --deep --strict "build/DIT Printer.app"
```

渲染 smoke test 已覆盖 TSPL、ZPL、EPL、CPCL、PDF，以及旧版打印配置回退逻辑。
Bridge smoke test 只写入临时任务目录，未执行真实打印和擦除。

## 九、前端接手重点

Antigravity 首先优化 `src/DITPrinterApp.swift` 的工作台体验：任务列表、信号审计
信息、复用次数输入、语言选择、模板编辑、同源预览、打印历史导出和错误恢复。
保持现有数据模型和桥接器接口。不要用营销首页替代工作台，不要把页面做成无法
扫描的装饰性卡片堆叠，也不要把“收到事件”显示成“打印完成”。

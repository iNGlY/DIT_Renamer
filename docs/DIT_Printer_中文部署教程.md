# DIT Printer 中文部署说明

DIT Printer 是独立的 macOS 标签打印工具，不包含在 DIT Renamer 1.1.1 中。推荐的触发条件是 Silverstack Copy Job 和其中的 Verify 均成功完成。

```text
源存储卡 -> Copy Job（Verify Included）-> 目标盘 1
                                      |-> DIT Printer 待打印标签
                                      |-> ParaShoot 可恢复擦除请求
```

DIT Printer 不会挂载、重命名、弹出、校验或删除摄影机卡。ParaShoot 桥接是另一条独立流程。即使 ParaShoot 支持恢复，擦除仍会改变卡的文件系统状态；正式使用前应在可丢弃测试卡上演练备份、校验、擦除、恢复和日志留存。

## 一次性安装

1. 构建应用：

   ```bash
   ./scripts/build_dit_printer.sh
   ```

2. 将 `build_printer/DIT Printer.app` 放入 `/Applications`，然后首次打开。Silverstack 脚本使用以下固定路径：

   ```text
   /Applications/DIT Printer.app/Contents/Helpers/DITPrinterBridge
   /Applications/DIT Printer.app/Contents/Helpers/ParaShootEraseBridge
   ```

3. 在 macOS 的“打印机与扫描仪”中安装目标打印机并确认它能出现在 CUPS 队列中。DIT Printer 不限定 GP-M325F：只要厂商驱动或 CUPS 队列能接受 PDF，就可使用通用 PDF 输出；支持 TSPL 的热敏标签机则可使用 Raw TSPL 输出。
4. 在 DIT Printer 的打印配置中选择一种输出方式，并保存为配置：

   - `CUPS PDF`：推荐的默认方式，适用于大多数 macOS 可打印的便携标签机与普通打印机。
   - `CUPS Raw command`：用于 GP-M325F 等标签机。当前支持 TSPL、ZPL、EPL/EPL2 和 CPCL；具体语言必须与打印机固件一致，队列必须允许 Raw 数据。
   - `Custom CLI`：给没有合适 CUPS 工作流的设备。填写绝对可执行文件路径，每行一个参数，并保留单独一行 `{file}`。应用会以 PDF 临时文件路径替换该占位符，直接启动该程序，不经过 shell。

5. 打开标签模板，选择预设尺寸，或填写名称、宽度、高度和间隙后保存。模板、打印配置都保存在当前 macOS 用户的偏好设置中，可以跨 Silverstack 项目使用；每次提交会把实际使用的模板和打印配置快照写进历史任务。

## 耗材与标签设计

内置尺寸覆盖中国大陆常见便携热敏标签耗材：`40 x 30 mm`（设备空间很紧时）、`50 x 30 mm`（小型卡盒）、`60 x 40 mm`（推荐的日常卡标签）、`72 x 51 mm`（推荐，信息最完整）和 `80 x 50 mm`（需要更大字体或更多字段时）。实际卷材的可打印高度、标签间隙与标称值可能不同，首次使用一个新品牌或型号时应先在废标签上校准，不要直接用于已完成的数据卡。

标签模板可编辑标题、页脚和自定义备注，并可独立勾选以下打印字段：Bin 名、最后一条素材、Copy Job 完成时间、卡复用次数、Silverstack 信号来源、DIT Printer 接收时间、源卷路径和自定义备注。小尺寸模板建议只保留 Bin、最后素材和复用次数；`72 x 51 mm` 及以上可加入完成时间与信号审计字段。

## 信号审计与打印历史

DIT Printer 收到桥接器 manifest 的瞬间会记录“Signal source”和“Received by DIT Printer”时间。这个时间证明应用何时收到来自 Silverstack 的事件，不等于物理打印机何时完成打印。Copy Job 完成时间由 Silverstack manifest 提供；提交成功后，历史还会记录提交时间、CUPS 队列或 CLI 结果、所用模板、打印配置和失败原因。

在主窗口工具栏选择导出图标，可以导出：

- CSV：便于在 Numbers、Excel 或制片日志中筛选。
- JSON：保留完整作业结构，适合归档或后续工具处理。

历史记录位于 `~/Library/Application Support/DIT Printer/Jobs`，是导出的来源。不要手工编辑这些 JSON 文件；需要调整待打印内容，请在 DIT Printer 中修改后重新提交。

## 配置 Silverstack 项目

1. 建立 Copy Job，并将 Verify 设为 **Included**。
2. 将以下脚本设为这个 Copy Job 的最终 Post Step：

   ```text
   src_printer/Silverstack/DITPrinterAndParaShootAfterCopyVerify.lua
   ```

3. 按以下顺序设置 Input Files：

   1. Source card
   2. Destination 1，也就是同一 Copy Job 实际校验的目标盘

4. 用测试卡完成一次 Copy + Verify。只有 Silverstack 返回 `success=true` 时，脚本才会启动两个桥接器。
5. 在 DIT Printer 中检查 Bin 名、末条素材名、完成时间、卡片复用次数和标签模板，然后提交打印。

每个 Silverstack 项目需要单独配置 Post Step，但同一台工作站可以继续使用已安装的应用、CUPS 队列和标签模板。

## 验收

- Copy 或 Verify 失败时，不应创建打印任务，也不应发送 ParaShoot 擦除请求。
- Copy + Verify 成功时，应只出现一条待打印任务；标签时间应与 Copy Job 完成时间一致。
- 切换项目后，已保存的标签模板仍可选择。
- 切换项目后，已保存的打印配置与导出的历史仍可使用；CSV 中应包含 Silverstack 信号来源、接收时间、Copy Job 完成时间和提交结果。
- 每种实际耗材连续打印至少 20 张，检查尺寸、间隙、起始位置和切纸位置。
- ParaShoot 结果应写入 `~/Library/Application Support/DIT Printer/ParaShootEraseJobs`，并完成一次恢复演练。
- 再次确认 Source 和 Destination 的顺序。顺序不正确时不要启用擦除流程。

## 常见问题

**标签偏移或尺寸不对**：检查模板中的宽度、高度和间隙。即使标称尺寸相同，不同厂商的耗材也可能需要单独校准和模板。

**普通打印机只打印到 A4 或内容缩放**：改用 `CUPS PDF` 配置，确认驱动中存在相近的自定义介质，或建立与耗材尺寸对应的 CUPS 预设。DIT Printer PDF 自带标签页面大小，但最终边距仍由厂商驱动决定。

**自定义 CLI 不执行**：可执行文件必须是绝对路径；参数一行一个，并且必须有单独的 `{file}` 参数。应用不会解释 `|`、`>`、`&&` 等 shell 语法，以避免素材名或路径被当作命令执行。

**切换 Silverstack 项目后找不到模板**：模板属于当前 macOS 用户，而不是 Silverstack 项目。确认应用运行在同一台工作站和同一用户下。

**ParaShoot 没有处理卡片**：检查 Copy Job 和 Verify 是否成功、Input Files 顺序是否正确、卡是否仍挂载在 `/Volumes`、ParaShoot 是否识别该卡，并查看桥接结果。不要用手工执行 `diskutil eraseDisk` 代替这条工作流。

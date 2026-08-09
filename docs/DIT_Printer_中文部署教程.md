# DIT Printer 中文部署教程

## 适用工作流

本教程适用于 macOS、Silverstack Lab、GP-M325F，以及启用 ParaShoot 的现场。
推荐工作流是一个 Copy Job 内包含 Verify：该任务成功完成后，同一 Lua Post
Step 会同时发送标签打印入队和 ParaShoot 可恢复擦除信号。

```text
源存储卡 -> Copy Job（Verify Included）-> 目标盘 1
                                      |-> DIT Printer 待打印标签
                                      |-> ParaShoot 可恢复擦除
```

ParaShoot 擦除会改变卡的文件系统状态。先用废卡完整演练备份、校验、恢复与日志
留存，再在正式项目启用。

## 一次性安装

1. 在本仓库执行：

   ```bash
   ./scripts/build_dit_printer.sh
   ```

2. 将生成的 `build_printer/DIT Printer.app` 安装到 `/Applications`，首次打开
   `DIT Printer.app`。桥接器的稳定路径为：

   ```text
   /Applications/DIT Printer.app/Contents/Helpers/DITPrinterBridge
   /Applications/DIT Printer.app/Contents/Helpers/ParaShootEraseBridge
   ```

3. 在 GP-M325F 上确认纸张类型为标签纸、指令集为 TSPL；在 macOS 的打印机设置中
   创建能接收 Raw TSPL 的 CUPS 队列，例如 `GP-M325F`。

4. 打开 DIT Printer，在每条待打印任务的 `Printer` 区选择该 CUPS 队列。

5. 在工具栏点标签图标，进入 `Label Templates`。选择预设耗材，或输入名称、宽度、
   高度、间隙（单位均为 mm），点 `Save template` 保存。
   在任务编辑区点眼睛图标可查看与实际 TSPL 共用同一位图渲染器的打印预览。

内置预设为 72 x 51、60 x 40、50 x 30、80 x 50 mm。自定义模板保存在当前 macOS
用户的 DIT Printer 偏好中，关闭应用、切换 Silverstack 项目后仍会保留。因此同一台
工作站的所有项目都可以选择同一模板；每次真正打印时，模板快照会写入该打印任务。

## 每个 Silverstack 项目的配置

1. 在 Silverstack 中建立 Copy Job，并将 Verify 设置为 **Included**。
2. 为这个 Copy Job 的最终 Post Step 导入：

   ```text
   src_printer/Silverstack/DITPrinterAndParaShootAfterCopyVerify.lua
   ```

3. 在 Post Step 的 Input Files 中严格按顺序选择：
   1. Source card
   2. Destination 1（当前 Copy Job 实际校验的目标盘）
4. 用一张测试卡完成一次 Copy + Verify。只有 `success=true` 时 Lua 才会后台启动
   两个桥接器。
5. 打开 DIT Printer，确认 Bin 名、末尾素材名、完成时间、复用次数和耗材模板，再
   提交标签打印。

同一套已安装的 `DIT Printer.app`、CUPS 队列和自定义耗材模板可以跨项目继续使用；
每个项目只需重复上述 Post Step 配置。不要复制或修改 bridge 可执行文件。若不同项目
使用不同标签纸，只需在 DIT Printer 选择另一个已保存模板。

## Lua 中文审阅说明

组合 Lua 文件内的每个关键区块均包含 `-- [中文审阅说明：...]`。这些都是 Lua
注释：只显示给人工审阅，不会传给 Silverstack、DIT Printer 或 ParaShoot，也不会改变
任务是否成功、标签内容或擦除条件。

## 验收清单

- 同一 Copy Job 失败或 Verify 失败时，不出现打印任务，也不启动 ParaShoot 擦除。
- Copy + Verify 成功时，DIT Printer 收到一条待打印任务；标签时间表示 Copy Job
  （含 Verify）完成时间。
- 切换项目后，已保存的耗材模板仍可选择。
- 依次打印每种真实耗材至少 20 张，确认 `SIZE`、`GAP`、起始位置和切纸位置。
- ParaShoot 审计目录 `~/Library/Application Support/DIT Printer/ParaShootEraseJobs`
  出现结果；再验证可恢复擦除后的恢复流程。
- 确认 Silverstack 的 Source/Destination Input Files 顺序。顺序不正确时不要启用
  自动擦除。

## 常见问题

**标签尺寸不对或偏移**：在模板库中检查宽、高、间隙；同一规格不同厂商纸卷仍可能
需要独立模板。不要修改现有模板后直接用于拍摄现场，先保存一个新名称并连续测试。

**换了 Silverstack 项目后找不到模板**：模板属于 macOS 用户，不属于项目。请确认在
同一台工作站、同一 macOS 用户下运行 DIT Printer。

**ParaShoot 没有擦卡**：检查 Copy Job 是否成功且 Verify Included、Input Files 顺序、
卡是否仍挂载在 `/Volumes`、ParaShoot 是否将其识别为卡，以及审计目录中的 bridge
输出。不要通过手工执行 `diskutil eraseDisk` 替代 ParaShoot。

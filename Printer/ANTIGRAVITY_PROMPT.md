# Antigravity 接手 Prompt

将下面整段 Prompt 交给 Antigravity IDE：

```text
你现在接手一个独立的 macOS SwiftUI 子项目：

/Users/Do2n4c7rY/Downloads/DIT_Renamer/Printer

请先完整阅读：

1. Printer/AGENTS.md
2. Printer/README.md
3. Printer/CONVERSATION_EXPORT.md
4. Printer/docs/部署教程_中文.md
5. Printer/docs/RENAMER_READ_ONLY_AUDIT.md

你的任务范围只有 Printer。绝对不要修改：

- ../src/
- ../src_swift/
- ../src/web/
- ../docs/ 中属于 DIT Renamer 的文档
- ../scripts/ 中属于 DIT Renamer 的脚本

如发现需要改变 DIT Renamer 才能完成 Printer 功能，请停下来，把需求写入
Printer/docs/ 中的阻塞说明，不要自行修改父项目。

产品目标：

DIT Printer 接收 Silverstack Copy Job 完成 manifest，创建独立打印任务。典型
任务是 Copy Job 的 Verify 设置为 Included in copy job。打印任务需要显示：
Silverstack Bin name、最后一条素材文件名、Copy 完成时间、信号来源、DIT Printer
收到信号的具体时间、源卷路径、操作者手动填写的卡复用次数。收到信号时间不能被
误写成打印机完成时间。

当前能力必须继续保留：

- CUPS PDF
- CUPS Raw command
- Custom CLI（绝对路径、直接 Process、参数逐行、{file} 占位符）
- TSPL、ZPL、EPL/EPL2、CPCL 原始命令生成
- 40x30、50x30、60x40、72x51、80x50 mm 模板预设
- 自定义模板的标题、页脚、备注、可选打印字段和持久化
- CSV/JSON 历史导出
- 旧 JSON 作业、旧模板、旧打印配置的向后兼容
- Silverstack bridge 和现有任务 JSON 存储

前端工作重点：

1. 把主窗口做成安静、可扫描的 DIT 工作台，而不是营销页。
2. 任务列表显示 Bin、最后素材、状态和收到信号时间。
3. 任务详情明确分组显示 Copy Event、Signal Audit、Card Reuse、Printer、Label
   Stock、History/Result。
4. 打印配置设置页要清楚区分 Output type 和 Printer language：
   - CUPS PDF 只显示 PDF。
   - CUPS Raw 显示 TSPL/ZPL/EPL/CPCL。
   - Custom CLI 显示 PDF/TSPL/ZPL/EPL/CPCL。
5. 预览必须使用真实提交同源的模板和渲染逻辑，不能做与实际输出不同的假预览。
6. 复用次数为空或非法时，打印操作必须明确阻止并显示原因。
7. 打印失败后保留任务、错误和重试入口，不能丢失历史。
8. 模板和配置编辑需要支持旧数据，并且保存后立刻反映在预览中。
9. 窄窗口、长 Bin 名、长文件名和中文内容不能造成控件重叠；优先截断或换行。
10. 使用现有 SwiftUI/AppKit 结构和图标风格，不要引入无必要的依赖。

安全边界：

- 开发和 UI 调试期间不调用 /usr/bin/lp，不执行任何自定义打印 CLI。
- 不调用 ParaShoot CLI，不运行擦除 bridge，不操作 /Volumes 下的真实卡。
- 不自动增加目标盘、不改变 Copy/Verify 结果、不挂载或弹出介质。
- ParaShootEraseBridge.swift 是高风险集成，前端工作不得修改。
- 不把中文审阅注释当作 Lua 有效业务输入。

验证要求：

在 Printer/ 中运行：

bash -n scripts/build_printer.sh
./scripts/build_printer.sh
codesign --verify --deep --strict "build/DIT Printer.app"

对 UI 修改至少运行 Swift typecheck 和现有 renderer smoke test。可使用 fixture
和临时 DIT_PRINTER_DATA_DIRECTORY 做 bridge 测试，但不要连接真实打印机或卡。
完成后报告改动文件、验证命令、未验证的硬件差异和任何需要用户现场确认的事项。
```

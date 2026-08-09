# DIT 相关 Skill 与工具检索

检索日期：2026-08-09

## 结论

截至本次检索，没有发现一个以 DIT（Digital Imaging Technician，数字影像工程师）为主题、已经发布到主流 Agent Skill 目录并可直接安装的成熟 AI Agent Skill。`skills.sh` 的公开检索结果没有命中 `DIT` 或 `Digital Imaging Technician` 专用技能；GitHub 中能找到的是 DIT 工具、Shell/Python 脚本、媒体校验标准和商业软件，而不是标准化的 `SKILL.md` 技能包。

这些资料仍然适合用来构建一个 DIT Skill，尤其覆盖：现场媒体卸载、双份/多份备份、checksum 校验、ASC MHL 清单、目录结构、日志和交接报告。

## 可复用的开源项目

| 项目 | 类型 | 可复用内容 | 安装/使用 | 来源 |
|---|---|---|---|---|
| `theSNEW/DIT-tools` | macOS Shell 工具 | DIT 目录结构、Working/Master/Clone 盘选择、`rsync` 批量复制、云端同步、JPG frame grab 同步 | 克隆仓库后按项目脚本和盘符配置使用；不是 Agent Skill | [GitHub 仓库](https://github.com/theSNEW/DIT-tools)；[DIT.sh](https://github.com/theSNEW/DIT-tools/blob/master/DIT.sh) |
| `FusinX/DIT_Offload` | Python GUI 工具 | `rclone` checksum 拷贝、双目标传输、磁盘空间预检、实时进度、日志、ASC MHL 创建与验证 | README 给出 Python 依赖和 `rclone`/`ascmhl` 安装方式；不是 Agent Skill | [GitHub 仓库](https://github.com/FusinX/DIT_Offload) |
| `WillZ5/DIT-Pro` | 开源 DIT 媒体卸载工具 | GitHub 检索摘要显示其面向片场数据管理，并强调 ASC MHL；建议在采用前审查代码、许可证和发布状态 | 可从 GitHub 获取；尚未将其视为稳定生产依赖 | [GitHub 仓库](https://github.com/WillZ5/DIT-Pro) |
| `ascmitc/mhl` | 行业标准参考实现/CLI | ASC Media Hash List 的创建、差异比较、验证、历史链和文件完整性记录 | Python 包/CLI：`pip3 install --upgrade ascmhl`；不是 Agent Skill | [GitHub 仓库](https://github.com/ascmitc/mhl)；[MHL 规范](https://github.com/ascmitc/mhl-specification) |

## 官方或商业 DIT 工作流资料

这些项目不是 AI Skill，但它们是设计 DIT Skill 行为规则时更可靠的参考：

- [Pomfort Silverstack XT](https://pomfort.com/silverstackxt/)：官方定位为 DIT/data manager 的专业生产数据处理软件，适合参考媒体拷贝、验证、元数据和报告工作流。
- [Pomfort Offload Manager](https://pomfort.com/offloadmanager/)：官方说明支持专业摄影机媒体格式并使用 checksum 进行拷贝验证。
- [Hedge OffShoot](https://hedge.co/products/offshoot)：面向媒体卸载和元数据控制的商业工具，适合参考现场数据拷贝的人机交互和校验流程。
- [ASC MHL 官方说明](https://github.com/ascmitc/mhl)：明确提出从片场初次下载到最终归档之间，用哈希记录每次复制，形成 chain of custody；这是自动化 DIT Skill 最值得固化的核心规则之一。

## 公开检索入口与排除项

- [skills.sh：DIT 关键词检索入口](https://www.skills.sh/search?q=DIT)：用于核验公开 Agent Skill 目录；本次没有发现 DIT 专用结果。
- GitHub 关键词：`Digital Imaging Technician`、`DIT data wrangler`、`DIT Offload`、`ASC MHL`、`camera media offload`。
- 搜索结果中的中文文章、课程和岗位说明可以用于学习 DIT 职责，但它们没有可安装的 Skill 包结构，因此未列入“可安装 Skill”。
- 注意区分另一个完全不同的 `DiT`：Diffusion Transformer。中文搜索中大量 `DiT` 结果属于机器学习模型，不属于数字影像工程师。

## 对本项目的建议

如果目标是给 Codex/Claude 等 Agent 使用，当前最现实的路径不是寻找现成包，而是基于上述资料编写一个本地 `SKILL.md`，并把项目现有的媒体扫描、重命名、报告和验证能力封装成只读优先的工作流。建议至少定义：

1. 卡/卷挂载识别与只读检查。
2. Working/Master/Clone 目标规划。
3. checksum 或 ASC MHL 验证后才允许标记为完成。
4. 文件计数、容量、失败项和日志报告。
5. 对格式化、删除、覆盖和相机卡操作设置明确的人工确认门槛。


# Sony FX3 自定义电影文件名研究

检索与核对日期：2026-08-28

## 结论

`B23_FX3B_20260827_0002.mp4` 与 `B23_FX3A_20260827_0001.MP4` **可以由 FX3 机内直接生成，并且高度符合 `File Name Format = Title + Date` 的结果**。最合理的解释是：

- `B23_FX3A_` / `B23_FX3B_` 是分别输入两台机身的自定义 `Title Name`；
- `20260827` 是相机按 `Title + Date` 模式加入的日期；
- `0001` / `0002` 是相机文件计数器；
- `.MP4` / `.mp4` 是扩展名，大小写差异不能用于判断文件是否经过第三方改名。

但 Sony 官方帮助指南只定义了字段顺序，没有在该页面给出 `Title + Date` 的完整带分隔符示例。因此，仅凭这两个文件名不能排除拍摄后由 Silverstack、剪辑软件、脚本或人工按相同模板重命名。要确认来源，应同时核对卡内原始目录、同名 `NonRealTimeMeta` XML、文件创建时间及拍摄日期；不要把文件名本身当作唯一证据。

这不是 Sony 定义的“含自定义项目名称的标准分机格式”。Sony 在 `Title` 模式下只把整段内容视为一个用户标题，并没有为 `B23` 定义“项目名”字段，也没有为 `FX3A` / `FX3B` 定义“机型 + 分机”字段。它更准确地说是：**用户利用 Sony 提供的通用 Title 功能，自行约定了一套项目/机位命名模板。**

## 官方事实

### FX3 的 Title 文件名模式

FX3 官方 Help Guide 的 `File Settings` 明确提供四种电影文件名格式：

- `Standard`：以 `C` 开头，例如 `C0001`；
- `Title`：`Title + File number`；
- `Date + Title`：`Date + Title + File number`；
- `Title + Date`：`Title + Date + File number`。

FX3 Ver.2 或更高版本的指南规定，`Title Name Settings` 最长为 37 个字符，可使用英文字母、数字以及这些符号：`. - _ @ ! # $ % + = ^ ~ ( ) , ; [ ]`。标题只影响设置完成后新录制的电影。使用 SDHC 卡时，文件名格式被锁定为 `Standard`；非标准格式应使用相应支持的介质。

来源：[Sony ILME-FX3 Ver.2 或更高版本 Help Guide：File Settings](https://helpguide.sony.net/ilc/2210/v1/en/contents/TP1000884355.html)（访问于 2026-08-28）。旧版 FX3 Help Guide 也记录了 `Title`、`Date + Title`、`Title + Date` 和 37 字符上限：[Sony ILME-FX3 Help Guide：File Settings](https://helpguide.sony.net/ilc/2035/v1/en/contents/TP1000283814.html)（访问于 2026-08-28）。

### FX3 的 Cam ID + Reel# 模式

FX3 固件 3.00 或更高版本另有 `Cam ID + Reel#` 格式。官方规则是：

`Camera ID + Reel number + Camera position + File number + Date + Random string`

官方示例为 `A001C001_230101AB`，其中：

- `Camera ID` 只能是 `A-Z`；
- `Reel Number` 是 `001-999`；
- `Camera Position` 是 `C/L/R`；
- 文件号达到 `999` 后，记录位置字母会推进，例如 `C999 -> D001`。

因此两个样本**不属于**这一标准格式：`B23` 不是“一个字母 + 三位 Reel”，`FX3A/FX3B` 也不可能是官方 `Camera ID` 字段。不能把样本中的 `FX3B` 解读为 Sony 标准 Camera ID。

来源：[Sony ILME-FX3 Ver.2 或更高版本 Help Guide：File Settings](https://helpguide.sony.net/ilc/2210/v1/en/contents/TP1000884355.html)（访问于 2026-08-28）。

### Catalyst 与元数据的边界

当前证据足以证明 FX3 机内具备生成该类名称的能力，但没有证据证明这两个具体文件是 Catalyst 生成或改写的。文件名不是可靠的机型元数据：`FX3A`、`FX3B` 都可能只是用户输入的标题文本。机型应继续以卡内 Sony `NonRealTimeMeta` XML 的 `Device modelName`（例如 `ILME-FX3`）或受控的媒体元数据读取结果为准。

即使 XML 确认机型为 FX3，它也只能增强“来自 FX3”的判断，不能单独证明 `B23`、`FX3A/FX3B` 的业务含义，也不能证明文件从未被第三方重命名。

## 对四段内容的判断

| 可见部分 | 最可能含义 | 自定义程度 | 证据强度 |
| --- | --- | --- | --- |
| `B23` | 项目、组别或拍摄单元简称 | 高；Sony 没有定义该独立字段 | 推断 |
| `FX3A` / `FX3B` | 用户约定的机型加 A/B 机标签 | 高；很可能属于 `Title Name`，不是 Sony Camera ID | 强推断 |
| `20260827` | `Title + Date` 模式自动加入的拍摄日期 | 很可能自动生成，但也可能被写入 Title 或后期模板 | 中高置信度推断 |
| `0001` / `0002` | 四位电影文件号 | 很可能由相机计数器生成 | 高置信度推断 |

若 `Title Name` 实际设置为 `B23_FX3A_` 或 `B23_FX3B_`，两者都只有 9 个字符，字符种类和长度完全满足 FX3 的官方约束。下划线可以由用户放进 Title；官方页面没有逐字符说明最终名称中哪些分隔符由相机额外插入，因此不能仅靠视觉拆分绝对确认字段边界。

## 论坛经验

DVXuser 的 FX6 文件命名讨论中，用户把 FX3/A7S III 描述为能够把日期加入文件名；同一讨论也说明不同 Sony Cinema Line 机型的命名能力并不相同，不能把 FX3 的规则直接套到 FX6。该内容与 FX3 官方 `Date + Title` / `Title + Date` 功能一致，但属于用户经验，不是规范证据。

来源：[DVXuser：Calling FX6 experts...](https://www.dvxuser.com/threads/calling-fx6-experts.5687729/)（讨论始于 2022-03-04，访问于 2026-08-28）。

## 为什么 1.3.0 没有进入自动重命名序列

当前 `MediaScanner` 对 Sony 自动建议采用的是电影行业卷号模式：

```text
^([A-Z])(\d{3})[CR]\d{3}_
```

它期望文件名以“一个字母 + 三位 Reel + `C/R` + 三位文件号 + 下划线”开头，例如 `A247C001_...`。通用后备规则也要求开头是“一个字母 + 三位数字 + 下划线”：

```text
^([A-Z])(\d{3})_
```

两个样本以 `B23_` 开头，只有两位数字，随后立即出现下划线，所以两条规则都不会匹配。扫描最终仍可通过 `M4ROOT` 和 XML 把介质显示为 Sony FX3，但会返回：

- `suggestedName = nil`；
- `cameraLetter = nil`；
- `rollNumber = nil`；
- `isHighConfidence = false`。

自动重命名要求存在有效建议名且候选为高置信度，因此该卡不会进入自动执行队列。这与扩展名是 `.mp4` 还是 `.MP4` 无关，扫描器会将扩展名转为小写后比较。

这里不能安全地把 `B23` 自动解释为 `B023`，也不能把四位电影文件号当作 Reel。Sony 官方没有为 Title 内部子段规定语义，因此 `FX3A/FX3B` 只可作为摄制组约定的机位线索，机型仍应由 XML 确认。

## 1.3.1 实现边界

1.3.1 增加独立的 FX3 `Title + Date` 兼容解析。规则只在以下条件同时满足时启用：

- 卡具有 `PRIVATE/M4ROOT` 或 `M4ROOT` 结构；
- Sony `NonRealTimeMeta` XML 以高置信度明确给出 `ILME-FX3`；
- 素材名符合“完整 Title + 有效八位日期 + 四位电影文件号”；
- 同卡电影素材使用同一完整 Title，Title 末段严格为 `FX3A` 至 `FX3Z`。

首次识别只预填机位，不自动创造 Reel，由操作员指定起始卷号。成功重命名后，软件从审计历史中的完整 Title、首素材和实际卷名建立序列；后续同一 Title 自动增加三位 Reel。多张同 Title 卡同时出现时预留连续卷号；卷号达到 `999`、XML 缺失、Title 混用或卡片身份不完整时继续交由人工确认。已成功重命名并重挂载的同一张卡必须同时匹配卷名和首素材，才会从待办中跳过。

## 事实、经验与推断的分层

- **官方事实**：FX3 支持 `Title`、`Date + Title`、`Title + Date`；Title 最长 37 字符并允许下划线；固件 3.00+ 的 `Cam ID + Reel#` 有完全不同的固定结构。
- **论坛经验**：FX3 用户确实会使用带日期的文件名；不同 Sony 机型的 Reel/文件号行为不能互相类推。
- **本次推断**：样本最可能是 FX3 机内 `Title + Date`，其中 `B23_FX3A_` / `B23_FX3B_` 是用户自定义 Title；但第三方重命名仍无法仅凭名称排除。

# ARRI Reference Tool CMD 与 CODEX Device Manager CLI 调研

调研日期：2026-08-09  
资料范围：仅使用 ARRI 官方网站、ARRI 官方用户手册和 ARRI 官方兼容性文档；未使用第三方文章或论坛信息。

## 结论

1. **ARRI Reference Tool CMD 1.0.0（可执行文件名 `art-cmd`）不是 CODEX Device Manager 的 CLI。** ARRI 将 ARRI Reference Tool CMD、ARRIRAW HDE Transcoder 和 CODEX Device Manager 作为不同产品列出。ARRI 对 CODEX Device Manager 的定义是 macOS 菜单栏工具及后台虚拟文件系统服务；`art-cmd` 则属于 ARRI Reference Tools，用于读取、修改、处理和检查 ARRI 摄像机文件。
2. `art-cmd` 1.0.0 手册只定义四个位置模式：`process`、`copy`、`verify`、`export`。恢复未封装完成的 MXF 属于 `copy` 模式的能力，不是第五个位置模式。
3. **没有发现“只估算 HDE 输出容量、不生成或处理输出”的命令或模式。** 手册未记录 `estimate`、容量预测、dry-run 或 size-only 操作；所谓 “Output size adjustment” 在手册中对应 `--output-width` / `--output-height` 的图像分辨率缩放，不是文件容量估算。
4. `art-cmd` 能读取 MXF/ARRIRAW-HDE 和旧式 `.arx` HDE 素材，但手册列出的输出格式不包含 HDE。ARRI 的 HDE Transcoder 页面进一步明确：经命令行 ARRI Reference Tool 剪辑或修复的素材需要交给 ARRIRAW HDE Transcoder，因为 ART CMD **不能导出 HDE**。
5. 本次核验的 ARRI 公开资料没有记录 CODEX Device Manager 的公开 CLI、`codex-hde` 可执行文件或对应命令。因此不能把 `art-cmd`，也不能把未经证实的 `codex-hde` 路径，视为 CODEX Device Manager CLI。

## `art-cmd` 1.0.0 记录的命令与能力

### 官方获取方式（macOS）

- ARRI 在 [ARRI Reference Tool 官方产品与下载页](https://www.arri.com/en/learn-help/learn-help-camera-system/tools/arri-reference-tool) 免费公开 ART CMD 1.0.0；页面标注 macOS 版本发布于 2026-01-22，下载包为 59.8 MB。
- [macOS universal 官方 ZIP 直链](https://www.arri.com/resource/blob/402592/d7dbcc61cfe76fcf5522e55e03bca2a4/arrireferencetool-cmd-1-0-0-macos-universal-data.zip)。解压后主程序位于 `art-cmd_1.0.0_macos_universal/bin/art-cmd`，同包还有 `look-builder`、schema、手册和 `EULA.txt`。
- 对官方包的本机只读核验显示 `art-cmd` 是 `x86_64 + arm64` 通用 Mach-O，并由 `Developer ID Application: Arnold & Richter Cine Technik GmbH & Co. Betriebs KG (34E6756YB7)` 签名。
- 官方包包含 `libcodexhdedecoder`，且 `art-cmd --help` 只把 HDE列为可处理的输入。参数清单没有 HDE 编码器、HDE 输出格式或容量预测选项。

这不是 Homebrew 包，也不应改名或伪装成 `codex-hde`。若未来集成，应用应让用户从 ARRI 官方页面取得工具、接受随包许可，并由设置项选择实际 `art-cmd` 路径；是否允许第三方应用调用和再分发仍需单独核对 EULA。

### 通用调用模型

- 基本形式为 `art-cmd <mode> --input <clip-or-directory>`。
- 支持多个 `--input`，也支持输入目录并递归批处理可读素材。
- `--start` 与 `--duration` 用帧范围限制处理区间，可用于剪辑输出。
- `--cli <json>` 读取符合随包 `cli.schema.json` 的 JSON 作业队列，依次执行多个调用。这里的 `--cli` 是 ART 自己的 JSON 作业入口，不代表 CODEX Device Manager CLI。
- `--metadata-overrides <json>` 可在生成新素材时覆盖受 schema 限定的一部分静态元数据。
- 软件包还包含独立的 `look-builder` 工具，用 CUBE 3D LUT 创建摄像机可用的 ARRI Look 文件。

### `process`

- 解码并改变图像数据，处理 ARRICORE、ARRIRAW、HDE 和 ProRes 输入。
- 支持 ARRIRAW/ARRICORE 解码参数、目标色彩空间、嵌入或外部 ARRI Look、批处理。
- 输出包括线性 OpenEXR、非线性色彩空间下的 MXF/ProRes，以及 16-bit TIFF。
- `--output-width` / `--output-height` 调整输出画面尺寸并保持宽高比；这不是容量预测。

### `copy`

- 保持视频和音频数据不变，将素材重封装为符合相关 SMPTE RDD 的 MXF，并转换/整理元数据标签。
- 可将旧式 MOV/ProRes、`.ari` ARRIRAW 及支持的旧式输入重封装为当前 MXF 表示。
- 配合 `--start` / `--duration` 剪辑素材。
- 可复制并重新完成因断电等原因未正确 finalized 的 MXF，恢复到最后一帧有效图像数据。
- 可应用受 schema 限定的元数据覆盖。

### `verify`

- 单输入时，利用素材元数据中的校验和验证视频帧；手册注明此方式只适用于 ARRIRAW/HDE，不适用于 MOV、MXF/ProRes 或 MXF/ARRICORE，因为后者缺少相应校验和元数据。
- 双输入时，对两个素材的视频、音频和元数据作成对比较。
- 支持目录批量校验，并通过 `--output <report.json>` 生成符合 `verify_report.schema.json` 的 JSON 报告。

### `export`

- 导出静态/逐帧动态元数据、原始音轨和素材中的 Look/LUT。
- 元数据可输出 JSON 或 CSV，音频输出 WAV；Look 可能包括 AML、ALF4、ALF4c、CUBE 及相关文件。
- 支持选择跳过元数据、音频或 Look，也支持目录批处理。

### 输入与输出边界

手册记录的输入包括：

- MXF/ARRICORE；
- MXF/ARRIRAW 与 MXF/ARRIRAW-HDE；
- MXF/ProRes 与旧式 MOV/ProRes；
- 旧式 `.ari` ARRIRAW 和 HDE 压缩的 `.arx` 帧序列。

手册记录的媒体输出包括 MXF/ARRICORE（仅 `copy`）、MXF/ARRIRAW（仅 `copy`）、MXF/ProRes、OpenEXR 和 TIFF，**没有 MXF/HDE 或 `.arx` HDE 输出**。

## 是否存在 size-only HDE 估算模式

公开的 1.0.0 手册不支持这一结论，理由如下：

- 手册完整模式清单只有 `process`、`copy`、`verify`、`export`。
- 通用参数、各模式参数和输入/输出格式章节均未记录 HDE 容量估算、仅扫描、dry-run 或不写输出的预测模式。
- HDE 在 ART CMD 中是可读取/校验的输入类型，不是已记录的输出编码类型。
- ARRI 官方 HDE Transcoder 页面明确说 ART CMD 不能导出 HDE，而真正执行 HDE 编码的替代工具是 ARRIRAW HDE Transcoder。
- ARRI 网页中的 “Output size adjustment also for ProRes clips” 与手册的 “Output scaling” 对应，指像素宽度/高度缩放，不能解释为输出文件字节数预测。

因此，DIT Renamer 若要提供 HDE 容量参考值，只能把它标记为**内部模型估算**，不能宣称数值来自 `art-cmd` 或已确认的 CODEX Device Manager CLI。该否定结论限定于本次核验的公开 ARRI 1.0.0 文档；若 ARRI/CODEX 后续提供未公开接口或新版命令，需要重新验证其官方文档与许可。

## 三类工具的区别

| 工具 | ARRI 官方定位 | HDE 角色 | 典型使用方式 |
| --- | --- | --- | --- |
| ARRI Reference Tool CMD (`art-cmd`) | ARRI Reference Tools 的命令行处理/检查工具；支持 ARRI 当前及旧世代摄像机文件 | 可读取、处理、校验 HDE 输入；1.0.0 未记录 HDE 输出 | 对素材执行处理、重封装/剪辑/恢复、校验、元数据/音频/Look 导出及批处理 |
| ARRIRAW HDE Transcoder | 标准 Device Manager 工作流无法使用时的替代 HDE 转码器 | 使用同一 CODEX 引擎把受支持的新式 MXF/ARRIRAW 编码为 MXF/HDE，可写多个目的地并生成 MHL/ASC MHL | GUI 可用于 macOS/Windows；命令行版本可用于 macOS、Windows、CentOS；ARRI 明确其不是标准 Device Manager 工作流的替代品 |
| CODEX Device Manager | macOS 菜单栏工具及后台虚拟文件系统服务 | 内置 HDE 编码器；检测摄像机介质上的 ARRIRAW，并呈现包含编码文件的虚拟 HDE 卷，供拷贝工具卸载 | 摄像机原始介质接入 Mac 后，后台自动、on-the-fly 工作；这是 ARRI 所称的标准 HDE 工作流 |

ARRIRAW HDE Transcoder 官方页面还限定其当前用途：只支持 ALEXA 35、ALEXA 35 Xtreme 和 ALEXA 265 的“new style” MXF/ARRIRAW。ARRI 的 2025 年 11 月兼容性表版本早于 ART CMD 1.0.0 手册，但表中分别列出 “ARRI Reference Tool (CMD)”、“ARRIRAW HDE Transcoder” 和 “CODEX Device Manager”，足以证明它们是不同的软件产品，不能互换名称。

## ARRI 第一方资料

- [ARRI Reference Tool CMD 1.0.0 User Manual](https://www.arri.com/resource/blob/402608/20ac446709713dfa4271aa47f633c439/arri-user-manual-art-cmd-v1-0-0-data.pdf)
- [ARRI Reference Tool 官方产品与下载页](https://www.arri.com/en/learn-help/learn-help-camera-system/tools/arri-reference-tool)
- [ARRIRAW HDE Transcoder 官方页](https://www.arri.com/en/learn-help/learn-help-camera-system/tools/arriraw-hde-transcoder)
- [ARRI High Density Encoding (HDE) 官方说明](https://www.arri.com/en/learn-help/learn-help-camera-system/pre-postproduction/file-formats-data-handling/high-density-encoding-hde)
- [ARRI Supporting Tools & Software — ALEXA 35 Xtreme & ALEXA 35（2025-11-07）](https://www.arri.com/resource/blob/288774/41b0e3dc02a4fd63d9f47a3621ffd6bc/arri-alexa-35-supporting-tools-and-software-data.pdf)

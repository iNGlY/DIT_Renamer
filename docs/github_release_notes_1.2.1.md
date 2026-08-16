# DIT Renamer 1.2.1

## 中文

1.2.1 把摄影机卡的型号识别改为统一的 Sidecar-first 流程：优先读取体积小、无需打开素材主体的摄影机原生元数据，并把证据来源和置信度显示在主窗口、菜单栏待办与审计记录中。

本版本新增：

- ARRI ALE：读取摄影机型号、ARRIRAW/Original Video 与 Reel 相关字段，继续支持 ALEXA 35、UDF 与配对 Codex HDE 卷。
- Sony NonRealTimeMeta XML：保留 FX3、FX6 和 Alpha 系列型号的可读映射；Sidecar 不足时可选用 ExifTool 检查一条代表素材。Canon、RED、DJI、Nikon 与 Blackmagic 也可在各自 Sidecar 只能确认工作流时使用同一受限后备。
- Panasonic P2 XML：从 `CONTENTS/CLIP` 的 `Device/Manufacturer/ModelName` 读取一致的具体型号，并修复 namespace 含 `nonRealTimeMeta` 时的误分类。
- Canon XML/XMP、RED RMD、DJI SRT/XMP、Nikon `.NEV` 与 Blackmagic `.sidecar`：在没有明确可靠字段时只显示工作流或产品族，不猜测具体机型。
- 防误报：NewsML/NewsItem/NewsMetadata、镜头型号、调色参数、文件名和目录签名都不能单独升格为具体摄影机型号；多个 Sidecar 型号冲突时自动降为低置信度。
- 修复 RED RDC/R3D 被 Nikon 命名规则抢先识别、DJI CinemaDNG 被当作照片卡或 Ronin 4D，以及 BRAW sidecar 后期字段被误当成机身信息的问题。
- 型号证据可进入重命名历史与 Printer 只读审计 v2，但不会保存 Sidecar 绝对路径、机身序列号或存储介质序列号。
- 继续支持缺少 Volume UUID 的卡片显示与手动重命名、规范卷名覆盖确认、重复目标卷名阻断、串行强制卸载/重挂载，以及 ARRI HDE 容量参考。

分发说明：

- Universal App，支持 Apple Silicon 与 Intel Mac，最低 macOS 14。
- 发布包使用 ad-hoc 签名，未进行 Apple notarization；首次安装请按 README 的图形界面步骤在“系统设置 > 隐私与安全性”中允许打开。
- App 已包含所需 Swift/Sparkle 运行组件，无需安装 Python、Java、Homebrew 或其它运行库。ExifTool 仅为 Sidecar/XML 无法给出具体机型时的可选后备。
- 本软件只修改卷名并重挂载同一分区，不复制、不校验、不擦除素材。请先用可丢弃测试卡验证现场读卡器和 Silverstack 工作流。

## English

DIT Renamer 1.2.1 moves camera identification to one sidecar-first path. It reads small camera metadata files before opening media content and exposes the evidence source and confidence in the main window, menu-bar review queue, and audit record.

Included in this release:

- ARRI ALE parsing for camera model, ARRIRAW/Original Video, and Reel-related fields, while preserving ALEXA 35, UDF, and verified Codex HDE support.
- Sony NonRealTimeMeta XML parsing with readable FX3, FX6, and Alpha model mapping. Optional ExifTool inspection of one representative clip remains available when sidecars are insufficient; Canon, RED, DJI, Nikon, and Blackmagic use the same bounded fallback when their sidecars identify only the workflow.
- Panasonic P2 XML parsing from `Device/Manufacturer/ModelName` under `CONTENTS/CLIP`, including the namespace case that also contains `nonRealTimeMeta`.
- Conservative Canon XML/XMP, RED RMD, DJI SRT/XMP, Nikon `.NEV`, and Blackmagic `.sidecar` handling. These formats remain at workflow or product-family level without explicit reliable model fields.
- False-positive protection: NewsML/NewsItem/NewsMetadata, lens models, grading settings, filenames, and directory signatures cannot independently become exact camera models. Conflicting sidecars are reduced to low-confidence workflow evidence.
- Fixed RED RDC/R3D media being captured by Nikon filename rules, DJI CinemaDNG being treated as a photo card or Ronin 4D, and post-production BRAW sidecar fields being treated as body information.
- Model evidence is available to rename history and the Printer read-only audit v2 interface without storing absolute sidecar paths, camera serial numbers, or media serial numbers.
- Preserved UUID-less card visibility and manual rename, confirmation before replacing standard volume names, duplicate-target blocking, sequential forced unmount/remount, and ARRI HDE size estimates.

Distribution notes:

- Universal App for Apple Silicon and Intel Macs; macOS 14 or later is required.
- The release is ad-hoc signed and not Apple-notarized. Follow the GUI-only README steps to allow the first launch in System Settings > Privacy & Security.
- Required Swift/Sparkle components are bundled. Python, Java, Homebrew, and other runtimes are not required. ExifTool is optional and used only when sidecar/XML metadata cannot provide an exact model.
- The App renames and remounts the same volume only. It does not copy, verify, or erase media. Validate the workflow with a disposable card and the installed Silverstack version first.

# 摄影机存储卡 Sidecar、XML、XMP 与索引元数据研究

更新日期：2026-08-16

## 研究目标与证据规则

本文评估 DIT Renamer 能否在**不读取媒体主体**的前提下，仅通过存储卡目录、XML/XMP、ALE、sidecar 或索引文件识别摄影机具体型号。范围包括 ARRI、Sony XAVC、Canon Cinema EOS/XF-AVC、Panasonic P2/VariCam、RED、DJI Ronin 4D/Inspire、Nikon N-RAW 和 Blackmagic BRAW。

证据等级：

- **官方保证**：厂商手册、元数据规范或官方 SDK 明确规定。
- **社区多例**：多个相互独立的现场实例一致，但厂商没有承诺稳定性。
- **社区单例**：单个帖子、样卡或目录截图，只能作为线索。
- **线索不足**：没有找到可复核、可跨机型复现的社区实例，不据此推导规则。

“不读取媒体主体”在本文中指不打开 `.MXF`、`.R3D`、`.NEV`、`.BRAW`、`.MOV`、`.MP4` 或 CinemaDNG 图像文件。仅读取文件名、目录、独立文本 sidecar、XML/XMP、ALE 或索引文件符合该定义。只读取媒体容器前部元数据虽然通常很快，但仍归类为“读取媒体文件”。

## 总结

| 厂商/格式 | 常见独立元数据 | 是否由摄影机稳定生成 | Sidecar 是否可识别具体机型 | 建议置信度 |
| --- | --- | --- | --- | --- |
| ARRI ALEXA/AMIRA | 卡根目录或素材组内的 `*.ale`；部分旧格式有 `*.xml` | 随录制格式与代际变化，但 ALEXA 35 每条素材的 per-shot metadata 会写入 ALE | **可以**，ALE 的 `Camera_Model`/`Camera_model` 可给出具体型号 | 高 |
| Sony XAVC/XDCAM | `NonRealTimeMeta` XML、Take XML/SMIL | XAVC 卡结构中常见，但随录制模式和目录结构变化 | **可以**，clip XML 的 `Device manufacturer/modelName/serialNo` 可给出具体型号 | 高（字段存在时） |
| Panasonic P2/VariCam | `CONTENTS/CLIP/*.XML` | P2 录制结构的一部分 | **可以**，`DEVICE` 元数据包含厂商、型号和序列号 | 高 |
| Canon Cinema EOS/XF-AVC | `CONTENTS/CLIPS001` 索引；部分模式有 `.CPF` 或用户 News Metadata XML | 随机型、封装和设置变化 | **通常不可以**；具体机型主要在 MXF/MP4 内部元数据 | 低至中 |
| RED | 同名 `.RMD` | 条件性；可由摄影机或软件保存 | **不可以稳定识别**；RMD 主要保存调色/解码覆盖值 | 低 |
| DJI Ronin 4D/Inspire | 条件性 `.SRT`、代理文件和格式相关辅助文件 | 随机型、固件、设置和录制格式变化 | **没有官方保证**；不能只因出现 DJI 目录就断言具体机型 | 低 |
| Nikon N-RAW | `.NEV`，可选同名代理 `.MP4` | NEV 必定；代理取决于设置 | **不可以**；没有官方定义的型号 sidecar | 低 |
| Blackmagic BRAW | 同名 `.sidecar` JSON | 条件性，修改元数据或图像参数后保存 | **不可以稳定识别**；相机类型由 `.braw` clip API 返回 | 低 |

结论：最适合直接加入“sidecar 优先识别”的是 **ARRI ALE、Sony clip `NonRealTimeMeta` XML 和 Panasonic P2 XML**。其他格式应把 sidecar 视为辅助证据，并在需要具体机型时读取单个媒体文件的受限头部或调用官方 SDK；不能用“文件存在”替代型号字段。

## 1. ARRI ALEXA / AMIRA

### 官方资料

- ARRI 明确说明 ALEXA/AMIRA 输出的完整元数据位于 ARRIRAW、MXF/ARRIRAW、ProRes 和 DNxHD 中，独立的 `*.ale` 与 `*.xml` 也会携带其中一部分信息。[ARRI Meta Extract](https://www.arri.com/en/learn-help/learn-help-camera-system/tools/legacy-software/arri-meta-extract) **（官方保证）**
- ARRI 的 ALEXA DNxHD 工作流文档列出 ALE/XML 可提供 `Camera_Model`、SUP 版本、曝光指数、白平衡、Look、快门角度、UUID 等字段。[ARRI ALEXA MXF/DNxHD White Paper](https://www.arri.com/resource/blob/31906/5041b6a03f1200b16e8815d1c7384f89/arri-mxf-dnxhd-white-paper-for-alexa-sup9-0-data.pdf) **（官方保证）**
- ARRI 当前说明明确指出，ALEXA 35、ALEXA 35 Xtreme 与 ALEXA 265 的 per-shot metadata 除写入媒体文件头外，也写入 ALE。[ARRI Visual Effects FAQ](https://www.arri.com/en/learn-help/learn-help-camera-system/image-science/vfx-faq) **（官方保证）**

### 项目样卡与社区证据

- 本项目当前 Codex Compact 样卡的 `*_AVID.ale` 已实测包含 `Manufacturer=ARRI`、`Camera_model=ALEXA 35`、Camera SN、Storage SN、SUP 版本、`Original_video=ARRIRAW`、Reel、EI、白平衡、镜头等。该样本与 ARRI 官方字段说明一致。**（本地实测 + 官方交叉验证）**
- 同卡的 `*_BIN.bin` 含素材 UUID、MXF 文件名、Look/Texture 和存储介质序列号，但未发现可靠的明文具体机型，因此不应把 BIN 作为首选型号来源。**（本地实测）**

### 判断

- **无需读取媒体识别具体机型：可以，置信度高。** 优先解析同卷 ALE 的字段标题，不依赖固定列序；多个 ALE/记录不一致时降级并提示。
- ALE 缺失时，仍应显示 ARRI/Codex 卷并允许手动重命名。具体机型可再通过受限读取一个 MXF/ARRIRAW 文件头或 ARRI 工具获得，不得因缺少 ALE 隐藏存储卡。

## 2. Sony XAVC / XDCAM / Cinema Line

### 官方资料与项目样本

- Sony 的 XAVC/XDCAM 卡结构使用 `NonRealTimeMeta` XML 保存 clip 级非实时元数据。项目已有 FX3/FX6 实际 XML，其中设备节点形如 `<Device manufacturer="Sony" modelName="ILME-FX3" ...>`；`modelName` 可直接区分 FX3、FX6、A7 系列等具体产品编号。**（项目样本）**
- Sony 官方产品页确认 FX3 的产品编号为 `ILME-FX3`，FX6 的地区型号可为 `ILME-FX6V`。实现应先保留原始型号，再通过维护表显示为 `FX3`、`FX6`，而不是对字符串做模糊猜测。[Sony FX3 产品注册页](https://www.sony.co.uk/mysony/product/register/express?cpint=mysony_glb-pdp_pre&modelname=ILME-FX3)；[Sony FX6 支持页](https://www.sony.com/electronics/support/camcorders-and-video-cameras-interchangeable-lens-camcorders/ilme-fx6v/downloads) **（官方保证产品编号）**

### 社区证据与限制

- Sony 用户的现场方法是打开每条 XAVC clip 对应 XML，读取 `<Device manufacturer="Sony" modelName="..." serialNo="...">`；该字段被用于从素材中恢复机身型号和序列号。[Reddit：Extract Serial Number from Sony Cameras](https://www.reddit.com/r/videography/comments/1bzpqdd/extract_serial_number_from_sony_cameras/) **（社区实测）**
- FX6 用户公开的故障卡实例显示，`Take` 目录中的 `NonRealTimeMeta` XML 可能只含 UMID、时长、时码和创建时间，并不一定包含 `Device`。同一卷上可能有多类 XML，因此扫描器不能“读到第一个 XML 就停止”，而应优先 clip 对应 XML，并寻找明确的 `Device` 节点。[Reddit：FX6 Missing clip but evidence it was recorded](https://www.reddit.com/r/SonyFX6/comments/16aqse7/fx6_missing_clip_but_evidence_it_was_recorded/) **（社区单例，但结构风险明确）**
- 不同 Sony 用户样本中的 XML 命名空间版本并不完全相同。实现应按元素 local name 与所需属性解析，不能硬编码单一 namespace 版本。**（社区观察，需继续用样卡扩充 fixture）**

### 判断

- **无需读取媒体识别具体机型：可以，字段存在时置信度高。** 必须同时验证根元素为 `NonRealTimeMeta`、目录符合 Sony 卡结构，并从明确的 `Device` 节点取得 `manufacturer` 与 `modelName`。
- XML 缺失、损坏或只有 Take/SMIL 信息时，仍应识别为 Sony 候选并允许手动重命名；可选后备是受限读取一个代表性 MP4/MXF 的元数据或调用 ExifTool。

## 3. Canon Cinema EOS / XF-AVC

### 官方资料

- Canon 当前 Cinema EOS 同时存在 XF-AVC/MXF 与 XF-AVC S、XF-HEVC S/MP4 等结构；官方强调这些格式保留 metadata，但没有保证每条素材旁必定存在一个含 `manufacturer`、`camera model` 或 `serial` 的独立 XML。[Canon EOS C400](https://www.canon-europe.com/cameras/eos-c400/)；[Canon EOS C400 specifications](https://www.canon-europe.com/cameras/eos-c400/specifications/) **（官方保证边界）**
- 新一代 Canon XF-AVC S/MP4 使用 `XFVC/REEL_****` 等目录，不能把传统 `CONTENTS/CLIPS001` 当作所有 Cinema EOS 的永久规则。[Canon：Selecting a Recording Method, Card/Folder](https://cam.start.canon/en/C023/manual/html/UG-08_Set-up_0030.html) **（官方保证）**
- Canon 的 “News Metadata” XML 只有在相应选项开启时才随素材保存；其来源为 NewsML-G2 新闻元数据，不是摄影机自动生成的硬件身份证明，不能据此保证获得机型或序列号。[Canon EOS R5 Mark II：News Metadata](https://www.usa.canon.com/support/p/eos-r5-mark-ii) **（官方保证）**
- `.CPF` 是 Custom Picture 文件，主要保存 gamma、色域、色彩矩阵与 Look 等图像配置；部分机型可选择创建或嵌入 CPF，但官方没有把它定义为稳定的机身型号或序列号来源。[Canon：Custom Pictures](https://cam.start.canon/en/C018/manual/html/UG-03_Shooting-2_0130.html)；[Canon EOS R50 V：Metadata](https://cam.start.canon/en/C021/manual/html/UG-04_Shooting_0430.html) **（官方保证）**

### 社区证据与限制

- Canon 社区和后期论坛能见到 `CONTENTS/CLIPS001`、MXF 分段、CPF/THM/XML 组合随机型和录制模式变化的报告，但本轮没有找到足够多、同时公开完整 XML 字段且可跨 Cinema EOS 机型复核的样例。可继续从 [Canon Community 搜索：XF-AVC XML](https://community.usa.canon.com/t5/forums/searchpage/tab/message?q=XF-AVC%20XML) 和 [Creative COW 搜索：Canon XF-AVC XML](https://creativecow.net/?s=Canon+XF-AVC+XML) 收集样卡。**（线索不足）**
- Canon C400 用户确认卡上会出现 XML 与 CPF，但在 DaVinci Resolve 中许多 Canon 摄影元数据仍需从 MXF 本体读取；这支持“文件存在不等于独立 XML 能给出完整型号”的保守策略。[Blackmagic Forum：Canon C400 metadata](https://forum.blackmagicdesign.com/viewtopic.php?f=21&t=221337) **（社区单例）**

### 判断

- **无需读取媒体识别具体机型：不可靠。** 仅目录可识别“疑似 Canon XF 系列媒体”，但具体机型应读取一个 MXF/MP4 的受限元数据区，或使用 Canon 官方工具/SDK 能力。
- 风险包括 XF-AVC 与 XF-AVC S 差异、跨卡分段、用户自定义 News Metadata、剪辑软件生成 sidecar，以及复制过程遗漏索引文件。

## 4. Panasonic P2 / VariCam

### 官方资料

- 标准 P2 卡在 `CONTENTS` 下包含 `VIDEO`、`AUDIO`、`ICON`、`VOICE`、`PROXY`、`CLIP` 等目录；`CONTENTS/CLIP` 保存每个 clip 的 XML 元数据。P2 介质应作为完整目录树处理，而不是只复制 MXF。[Panasonic Professional AV：Operating Instruction Manuals](https://pro-av.panasonic.net/manual/en/)；在型号手册中检索 “P2 card recording data” 或 “Folder structure of the P2 card” **（官方保证）**
- Panasonic 的 P2 clip metadata 将 `DEVICE` 定义为录制设备信息，常见项目包括 `MANUFACTURER`、`SERIAL NO.` 和 `MODEL NAME`；其他项目还包括 Global Clip ID、clip 名、帧率、开始时间码、视频 codec、音频 codec、拍摄日期以及用户 clip 名。[Panasonic Professional AV：manual search](https://pro-av.panasonic.net/manual/en/)；可检索 AJ-PX380、AJ-PG50、AG-HPX600 的 “clip metadata” 章节 **（官方保证）**
- VariCam LT 手册的 clip metadata 项同样列出记录设备制造商、序列号和型号，因此 P2/VariCam XML 是本研究中最明确的无媒体读取机型来源。[Panasonic VariCam LT support](https://pro-av.panasonic.net/manual/en/)；检索 “VARICAM LT” 和 “clip metadata” **（官方保证）**
- 部分 P2 metadata 项可由用户编辑，但设备制造商、型号、序列号等录制设备字段由摄影机记录；实现时仍应按 XML 节点语义读取，不应依赖固定行号。[Panasonic AG-CX350：Clip metadata](https://pro-av.panasonic.net/manual/html/AG-CX350EJ%28DVQP1833SA%29_E/chapter05_08_07.htm)；[P2 Contents Management Software](https://pro-av.panasonic.net/en/software/p2cms/) **（官方保证）**

### 社区证据与限制

- 后期社区长期把 `CONTENTS/CLIP/*.XML` 作为恢复 P2 clip 关系、时间码和拍摄元数据的关键文件，且普遍强调必须保留整个 `CONTENTS` 与 `LASTCLIP.TXT`。可参考 [Creative COW 搜索：P2 CLIP XML](https://creativecow.net/?s=P2+CLIP+XML) 与 [DVXuser 搜索：P2 XML](https://www.dvxuser.com/search/?q=P2%20XML)；这些实例支持目录结构的稳定性，但不能替代型号手册。**（社区多例）**
- 现场风险包括不完整拷贝、XML 损坏、经过 NLE 重建的虚拟 P2 卡、跨卡 spanned clip，以及非 P2 的 VariCam 录制模式。看到 `CONTENTS/CLIP` 才应用 P2 解析器；仅看到 Panasonic 文件名不够。

### 判断

- **无需读取媒体识别具体机型：可以，置信度高。** 至少需要成功解析一个摄影机原生 `CONTENTS/CLIP/*.XML`，且多个 XML 的 `MANUFACTURER`/`MODEL NAME` 应一致。
- 建议在模型映射前保留原始 `MODEL NAME`，并把序列号只用于审计或冲突排查，不写入卷名。

## 5. RED / R3D

### 官方资料

- RED `.RMD` 是与 `.R3D` 同名的 sidecar，保存用户调整后的 clip 设置；REDCINE-X PRO 可从 RMD 加载、保存或清除设置。它不是摄影机身份清单。[RED：RMD Files](https://docs.red.com/955-0004/REDCINE-XPROOperationGuide/Content/6_Export/RMD.htm)；[RED：RMD Menu](https://docs.red.com/955-0004_v51/REDCINE-XPROOperationGuide/Content/3_Clip_Settings/RMD_Menu.htm) **（官方保证）**
- RED 的 camera metadata（例如 Camera ID、Reel、ISO、白平衡、镜头及录制参数）由 R3D clip 元数据提供，并由 REDCINE-X 的 Metadata 面板读取；官方没有承诺 RMD 一定复制 camera model 或 camera serial。[RED：Metadata](https://docs.red.com/955-0004_v52/REDCINE-XPROOperationGuide/Content/5_Organize/Metadata.htm) **（官方保证）**
- RED 文件名编码 Camera ID、Reel ID、clip 编号和日期等生产信息，但 Camera ID 是用户/项目标识，不等于具体机身型号。[RED：Clip Naming Conventions](https://docs.red.com/955-0157_v6.2/WEAPONGEMINI_OperationGuide/Content/4_Menus/ProjSet/Clip_Naming.htm) **（官方保证）**

### 社区证据与限制

- RED 用户社区常见 RMD 用于跨 REDCINE-X/Resolve 传递 IPP2、ISO、色温和曝光调整，但不同软件写出的 RMD 内容和创建时机不同。本轮未取得足够多公开的原始 RMD 样本来证明某个机型字段稳定存在。可继续查阅 [REDUSER 搜索：RMD sidecar](https://www.reduser.net/search?q=RMD%20sidecar) 和 [LiftGammaGain 搜索：RED RMD](https://www.liftgammagain.com/forum/index.php?search/&q=RED%20RMD) **（社区多例支持“调色 sidecar”；机型字段线索不足）**

### 判断

- **无需读取媒体识别具体机型：不可靠。** RMD 可作为“这是 RED 工作流”的弱证据；具体型号应通过 RED SDK 或受限读取一个 R3D 的 clip metadata。
- 不应把 `A001`、Camera ID 或 Reel ID 映射成 RED 机型。RMD 缺失也不应降低真实 R3D 卡的可见性。

## 6. DJI Ronin 4D / Inspire

### 官方资料

- Ronin 4D 使用 Zenmuse X9 系列云台相机并支持 CFexpress Type-B/PROSSD 等介质；官方用户手册描述录制格式、代理及存储操作，但没有保证每条素材旁生成一个包含 “Ronin 4D” 或机身序列号的 XML。[DJI Ronin 4D User Manual v1.4](https://dl.djicdn.com/downloads/DJI_Ronin_4D/20231214/DJI_Ronin_4D_User_Manual_v1.4_cn.pdf) **（官方保证边界）**
- Inspire 3 使用 Zenmuse X9-8K Air，并支持 CinemaDNG、ProRes RAW/ProRes 和 H.264/H.265 等不同工作流；辅助文件随格式和设置变化，官方手册没有把某个 XML/XMP 定义为必定包含具体机型的身份证明。[DJI Inspire 3 User Manual v3.0](https://dl.djicdn.com/downloads/inspire_3/20241016UM/DJI_Inspire_3_User_Manual_V3.0_CHS_.pdf) **（官方保证边界）**
- DJI SDK 对部分产品的 “Video Caption” 定义为可选字幕元数据，生成 `.SRT`，内容可包括 ISO、光圈和快门等拍摄参数；该开关和字段不是 Ronin 4D/Inspire 具体机型识别保证。[DJI Mobile SDK：Camera Settings Definitions](https://developer.dji.com/api-reference/android-api/Components/Camera/DJICamera_DJICameraSettingsDef.html)；[DJI Mobile SDK：Camera](https://developer.dji.com/api-reference/android-api/Components/Camera/DJICamera.html) **（官方保证，仅适用于 SDK 支持范围）**

### 社区证据与限制

- DJI 论坛和用户社区可见不同固件、录制 codec 和存储介质产生不同代理、SRT、音频或图像序列布局，但本轮没有找到可跨 Ronin 4D 与 Inspire 3 重复验证、且公开完整机型字段的 sidecar 样本。[DJI Forum 搜索入口](https://forum.dji.com/)；[Reddit 搜索：Ronin 4D card structure](https://www.reddit.com/search/?q=Ronin%204D%20card%20structure)；[Reddit 搜索：Inspire 3 file structure](https://www.reddit.com/search/?q=Inspire%203%20file%20structure) **（线索不足）**

### 判断

- **无需读取媒体识别具体机型：目前不可靠。** 目录和 codec 可以形成品牌/产品族候选，但 Ronin 4D、Inspire 3 及其他 X9 产品可能共享相似标记。
- 实现时应组合根目录签名、codec、独立 metadata 字段和一个媒体头部；只凭 `DJI_` 文件名、`DCIM`、`.SRT` 或 CinemaDNG 目录不得硬编码成 Ronin 4D/Inspire 3。

## 7. Nikon N-RAW

### 官方资料

- Nikon N-RAW 使用 `.NEV` 文件。官方手册将 N-RAW 定义为视频文件类型，而不是带独立 XML/XMP 的目录格式。[Nikon Z9：Video File Types](https://onlinemanual.nikonimglib.com/z9/en/video_file_types_32.html) **（官方保证）**
- N-RAW 工作流会同时记录同名 `.MP4` 代理；代理是视频文件，不是专门的机型 sidecar。[Nikon Z9：File Naming](https://onlinemanual.nikonimglib.com/z9/en/psm_file_naming_89.html)；[Nikon Z9：RAW Video](https://onlinemanual.nikonimglib.com/z9/en/raw_video_guid-28d23f42-5291-3c99-a22b-03a47190f478_30.html) **（官方保证）**

### 社区证据与限制

- 社区中能见到 Resolve、Premiere、ExifTool 对 `.NEV` 支持差异的讨论，但本轮没有找到多台 Nikon N-RAW 机身、多个固件版本的原始 sidecar 样本，因为主元数据通常位于 NEV 容器内部。[ExifTool Forum 搜索入口](https://exiftool.org/forum/)；[Reddit 搜索：Nikon N-RAW NEV metadata](https://www.reddit.com/search/?q=Nikon%20N-RAW%20NEV%20metadata) **（线索不足）**

### 判断

- **无需读取媒体识别具体机型：不可靠。** 文件扩展名可确认 N-RAW 产品族，但不能区分 Z9、Z8、Z6III 等支持机型。
- 最合理方案是对一个 `.NEV` 执行受限元数据读取；如果所用解析器不支持 NEV，应只显示“Nikon N-RAW”，不要猜测具体型号。

## 8. Blackmagic BRAW

### 官方资料

- Blackmagic RAW SDK 明确规定 `.sidecar` 是文本 JSON，用于保存原始 `.braw` 生成后被修改的 metadata、白平衡、ISO、图像处理参数和 3D LUT；只有用户或软件保存修改时才会存在，可删除以恢复 clip 原始状态。[Blackmagic RAW SDK，第 1.2 节 Sidecar](https://documents.blackmagicdesign.com/DeveloperManuals/BlackmagicRAW-SDK.pdf?_v=1754550010000) **（官方保证）**
- 官方 SDK 通过 `IBlackmagicRawClip::GetCameraType()` 返回录制该 clip 的 camera type；该调用先打开 `.braw` clip。SDK 没有把 camera type 定义为 `.sidecar` 的必填 JSON 字段。[Blackmagic RAW SDK，第 2.2 节及 `GetCameraType`](https://documents.blackmagicdesign.com/DeveloperManuals/BlackmagicRAW-SDK.pdf?_v=1754550010000) **（官方保证）**
- SDK 的 clip metadata iterator 可读取 clip 级 metadata，sidecar 可覆盖部分 metadata；因此需要区分“原始 BRAW 内嵌字段”和“后期保存的覆盖值”。[Blackmagic RAW SDK and Software](https://www.blackmagicdesign.com/developer/products/braw/sdk-and-software) **（官方保证）**

### 社区证据与限制

- Blackmagic 官方论坛中常见 Resolve/Player 创建 `.sidecar`、共享调色设置或 sidecar 冲突的案例，支持其“后期覆盖文件”定位；没有稳定证据表明所有摄影机原生卡都会有 sidecar，或 sidecar 必含机型。[Blackmagic Forum 搜索：BRAW sidecar](https://forum.blackmagicdesign.com/search.php?keywords=BRAW+sidecar)；[Reddit 搜索：BRAW sidecar metadata](https://www.reddit.com/search/?q=BRAW%20sidecar%20metadata) **（社区多例支持创建条件；机型字段线索不足）**

### 判断

- **无需读取媒体识别具体机型：不可靠。** `.sidecar` 存在时可作为 BRAW 工作流辅助证据，但具体 camera type 应由官方 SDK 打开一个 `.braw` 后读取。
- 读取 BRAW clip metadata 不要求解码完整画面，通常比全媒体扫描轻得多，但仍属于访问媒体文件；实现应设置超时、只取首个代表 clip，并缓存结果。

## 推荐的识别优先级

1. 先按卷内目录和扩展名判断候选厂商，不因 UUID 或 sidecar 缺失隐藏存储卡。
2. 对 ARRI，先解析 ALE 的 `Camera_Model`/`Camera_model`；BIN 仅作 clip 关系和存储介质辅助证据。
3. 对 Sony，遍历受控数量的候选 clip XML，寻找 `NonRealTimeMeta/Device`；跳过只含 Take/SMIL 信息的 XML，并兼容不同 namespace 版本。
4. 对 Panasonic P2/VariCam，优先解析 `CONTENTS/CLIP/*.XML`；只有字段存在且多个 clip 一致时输出具体型号。
5. 对 Canon，解析明确的官方 XML/XMP 字段时只使用其实际值；News Metadata、CPF 和目录名不能单独证明具体机型。
6. 对 RED、Nikon N-RAW、Blackmagic BRAW，在 sidecar 不能提供稳定 camera model 时，读取一个代表媒体的受限头部或调用官方 SDK。不要遍历全部素材。
7. 对 DJI，将目录、X9 产品族、codec、SRT/代理文件视为组合证据；在没有明确 model 字段时显示“DJI 摄影机介质”或“Zenmuse X9 系列”，不要强行区分 Ronin 4D 与 Inspire 3。
8. 所有识别结果都应保存来源类型：`official-sidecar-field`、`container-metadata`、`directory-signature` 或 `inferred-family`，并在 UI/审计中映射为高、中、低置信度。
9. sidecar 解析失败、字段冲突或未知固件只能降低型号置信度，不得阻止卷显示和手动重命名。

## 解析安全与性能约束

- 只扫描已知目录与扩展名；每卷限制候选文件数量，优先最新或最小的代表性元数据文件。
- XML/ALE 建议设置 1–4 MB 单文件上限，使用 Swift `XMLParser` 流式读取；禁用外部实体、网络资源和外部 DTD。
- 只接受明确字段路径，不对 XML 全文执行“型号关键词搜索”；限制嵌套深度、字段长度和累计读取字节。
- 首个有效高置信度型号出现后，再抽查少量文件确认一致性；结果按卷的挂载实例缓存，卷变化后失效。
- 只在独立元数据不足时读取一条代表媒体的有限头部；ExifTool 或厂商 SDK 为可选后备，不应成为卷是否可见或可手动重命名的前置条件。

## 可实施性结论

- **可直接、无媒体读取、高置信度实现：ARRI ALE、Sony clip XML、Panasonic P2/VariCam XML。**
- **可无媒体读取但只能识别产品族或工作流：Canon、RED、DJI、Nikon、Blackmagic。**
- **要可靠识别具体机型，通常仍需读取一个代表媒体文件的有限元数据区：Canon XF-AVC、RED R3D、Nikon NEV、Blackmagic BRAW；DJI 还需要真实样卡验证具体格式。**
- 该策略不会要求扫描完整媒体，也不应明显拖慢挂载识别：sidecar/XML 可先行；容器读取只在 sidecar 无法给出具体型号时，对单个代表文件执行并缓存。

## 研究限制

- 厂商会随固件、录制格式、代理设置和后期软件改变辅助文件，本文不把“未在手册中出现”解释为“文件绝对不存在”。
- 社区搜索结果中的目录截图和字段样本数量不均。Panasonic P2 有较多一致实践；DJI、Nikon N-RAW 的公开原始目录/sidecar 样本明显不足。
- 论坛搜索链接可能随站点索引变化；它们只用于继续收集现场样卡，不构成产品保证。
- 在加入生产识别规则前，应针对每个目标机型保存脱敏后的完整目录树、一个 sidecar/XML 样本、固件版本和录制格式，并建立 fixture 测试。

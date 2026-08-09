# DIT Renamer Swift 1.1 厂商规则研究

> 研究资料，不是自动命名规则。
>
> 检索日期：2026-08-09（Asia/Shanghai）
>
> 适用范围：为 DIT Renamer Swift 1.1 设计识别、人工复核和安全提示时提供官方资料索引。本文不授权程序直接改写卡内目录、素材文件名、Camera ID、Reel/Roll 或 Clip；“未确认”就是结论，不应用第三方经验替代。

## 1. 证据边界

“卡内目录”“素材命名”“Camera ID”“Reel/Roll”“Clip”“默认未配置命名”不是同一个字段。厂商手册可能只说明其中一个，例如 Nikon ZR 明确说明视频文件名由 Camera ID、Reel number、Clip number、日期和随机 ID 组成，但 DJI Ronin 4D 的官方规格页只确认存储介质、文件系统和编码格式。除非一手资料明确把字段定义为可读的相机标识或卷号，本文不把文件名前缀、日期、哈希、卷标或目录名推断成 Camera ID/Reel。

“默认未配置”仅在厂商资料明确写出默认值或未配置时的结果时记录。相机出厂文件名、用户关闭某项命名开关后的普通文件名、以及空卡/重格式化卡，不应混为一谈。

## 2. 相机厂商资料

### 2.1 Sony ILME-FX3

**官方确认**

- Sony FX3 Help Guide 的 `File/Folder Settings` 只针对 still image：`Set File Name` 可以指定文件名前三个字符；只能用大写字母、数字和下划线，首字符不能是下划线。官方给出的标准文件夹示例是 `100MSDCF`，日期文件夹示例是 `10010405`。这证明 FX3 存在可配置的照片文件名前缀和照片文件夹策略，不证明存在电影机式 Camera ID/Reel/Roll 字段。[Sony FX3 Help Guide - File/Folder Settings](https://helpguide.sony.net/ilc/2035/v1/en/print.html#TP1000283813)
- 官方手册说明 FX3 支持 CFexpress Type A 和 SD 卡，并区分 exFAT 与 FAT32；这可用于只读识别文件系统和卡介质，但不能从文件系统推导卷号。[Sony FX3 Help Guide - Memory cards that can be used](https://helpguide.sony.net/ilc/2035/v1/en/print.html#TP1000266582)

**逐项结论**

| 项目 | FX3 官方结论 |
|---|---|
| 卡内目录 | 照片目录/文件夹机制如上；电影卡的完整目录树、每种记录格式对应的目录树：**未确认**。 |
| 素材命名 | 照片可配置前三字符；电影素材的 Camera ID/Reel/Roll/Clip 组合：**未确认**。 |
| Camera ID | **未确认**。FX3 Help Guide 的 `Set File Name` 是照片文件名前缀，不能直接命名为 Camera ID。 |
| Reel/Roll | **未确认**。 |
| Clip | 电影 Clip 字段及其是否固定 `C####`：**未确认**。单凭 `C0001` 不能识别 FX3。 |
| 默认未配置命名 | **未确认**。官方页面没有把某个默认电影文件名定义为“未配置 Camera ID”。 |

### 2.2 Sony ILME-FX6

- Sony 的官方产品页确认 FX6 是专业 Cinema Line 摄影机，并提供官方支持资源入口；本次可公开访问的该页没有给出卡内目录树、Camera ID、Reel/Roll、Clip 或“未配置”电影文件名的字段说明。[Sony ILME-FX6 product page](https://pro.sony/en_GB/products/handheld-camcorders/ilme-fx6)
- 因此，FX6 的以下项目均记为 **未确认**：完整卡内目录；素材命名语法；Camera ID；Reel/Roll；Clip；默认未配置命名。需要以具体固件版本的 FX6 Operating Instructions/Help Guide 中的文件命名章节复核。不能因为 FX3、ARRI 或项目样例中出现 `A001`、`B003`、`C0001` 就填入 FX6。

### 2.3 Sony PXW-FX9

- Sony 的官方 Cinema Line 产品资料入口是厂商一手资料，但公开产品页本身不构成文件命名语法说明。[Sony Professional product/support entry](https://pro.sony/en_GB/products/handheld-camcorders)
- 对 PXW-FX9，本文没有找到可以在公开官方资料中逐项核对卡内目录、Camera ID、Reel/Roll、Clip 和默认未配置电影文件名的稳定版本化章节，因此上述项目均为 **未确认**。FX9 的记录格式、媒体类型和固件可能改变目录/命名行为，必须按具体固件手册处理。

### 2.4 Sony VENICE

- Sony 官方资料将 VENICE 归入 Digital Cinema Cameras，但产品宣传/规格页不能替代对应固件的操作手册。[Sony Professional Digital Cinema Cameras](https://pro.sony/en_GB/products/digital-cinema-cameras)
- VENICE 的卡内目录、素材命名、Camera ID、Reel/Roll、Clip 和默认未配置命名：**未确认**。尤其不能把 FX 系列的文件名正则套到 VENICE；即使两个机型都使用 Sony 媒体，记录格式和目录结构也可能不同。

### 2.5 Canon Cinema EOS

Canon Cinema EOS 是产品族，不是一个统一的目录/命名协议。应按 C70、C300 Mark III、C500 Mark II、C400、C80 等具体型号和固件逐本核对。

- Canon 官方手册门户明确说明其内容包含 Cinema EOS cameras 的说明书入口；但当前公开门户将地区/经销商选择作为前置步骤，不能把门户分类页当作某一型号的命名规则。[Canon product manual portal](https://cam.start.canon/en/)
- Canon EOS C70 的官方产品页能确认型号和 Cinema Camera 属性，但没有在公开产品页中定义 Camera ID、Reel/Roll 或 Clip 文件名字段。[Canon EOS C70 official product page](https://www.usa.canon.com/shop/p/eos-c70)

**按型号结论**

| 型号 | 卡内目录 | 素材命名 / Camera ID / Reel-Roll / Clip | 默认未配置命名 |
|---|---|---|---|
| EOS C70 | **未确认** | **未确认** | **未确认** |
| EOS C300 Mark III | **未确认** | **未确认** | **未确认** |
| EOS C500 Mark II | **未确认** | **未确认** | **未确认** |
| EOS C400 / C80 及其他 Cinema EOS | **未确认** | **未确认** | **未确认** |

资料缺口是 Canon 具体型号/固件的官方 Operating Instructions 中的“文件名、文件夹、剪辑编号、卷号”章节。不能以 Canon 照片机的 `EOS_DIGITAL`、`IMG_####` 或第三方的 `A001_C001` 经验代替。

### 2.6 ARRI ALEXA

- ARRI ALEXA 的官方用户手册体系把相机、记录格式、媒体和后期工作流分开说明。ALEXA Mini LF 官方产品页提供版本化 User Manual 下载；该手册体系使用由相机索引/卷计数、Clip 计数及日期/唯一部分组成的电影素材命名模型。官方示例中的核心关系可概括为 `Camera Index + Reel counter + Clip counter`，不是一个通用“卡卷卷标”。[ARRI ALEXA Mini LF product page and downloads](https://www.arri.com/en/cine-systems/cine-cameras/alexa-mini-lf)；[ALEXA Mini LF SUP 7.3 User Manual PDF](https://www.arri.com/resource/blob/347174/dc4492e9149f5b0696d4fdea351ea5e0/alexa-mini-lf-sup-7-3-user-manual-data.pdf)
- ARRI 官方资料也提供统一的 Technical Downloads 入口；ALEXA 35、ALEXA LF、ALEXA Mini LF、ALEXA Mini、ALEXA 65 的手册/固件版本不能无条件互换。[ARRI Technical Downloads](https://www.arri.com/en/learn-help/learn-help-camera-system/technical-downloads)

**按系列结论**

| 系列 | 官方可安全使用的结论 | 仍需逐型号/固件复核 |
|---|---|---|
| ALEXA / ALEXA XT / SXT / LF / Mini LF | 官方命名模型可表达 Camera Index、Reel/卷计数和 Clip 计数；示例中的日期/唯一后缀不是 Camera ID 或 Reel。 | 完整卡内目录、各记录格式目录、默认索引/卷号、恢复/换卡后的计数行为。 |
| ALEXA 35 | 有独立版本化手册和技术资料入口。 | 不能直接把 Mini LF 的完整目录和所有后缀规则移植到 ALEXA 35；本次研究将其具体目录/默认值记为**未确认**。 |

### 2.7 ARRI AMIRA

- AMIRA 属于 ARRI 另一条产品/固件线。ARRI 官方下载入口提供 AMIRA 的用户资料；其素材命名在官方手册体系中使用 Camera Index、Reel/卷计数、Clip 计数和日期/唯一部分这一类字段，但精确后缀、媒体格式和目录树必须以 AMIRA 固件手册为准。[ARRI AMIRA product/support entry](https://www.arri.com/en/cine-systems/cine-cameras/amira)；[ARRI Technical Downloads](https://www.arri.com/en/learn-help/learn-help-camera-system/technical-downloads)
- AMIRA 的默认 Camera Index、默认 Reel/Roll、卡上完整目录、不同 codec 的目录差异以及“未配置”文件名：**未确认**。因此 `A001_C001_...` 只能作为需要人工核对的观察值，不能作为自动规则。

### 2.8 RED Digital Cinema

- RED 官方支持中心按 V-RAPTOR/V-RAPTOR XL、KOMODO/KOMODO-X、DSMC2/RANGER、DSMC 等产品线分别提供资料；该组织方式本身说明 RED 不是一个可以不分型号的命名协议。[RED Support - Guides & Downloads](https://support.reddigitalcinema.com/hc/en-us)
- RED 官方资料确认 R3D 是其素材格式和相机工作流的一部分，但本次公开可访问的官方页面没有提供一份覆盖所有 RED 型号、固件和媒体的统一“Camera ID + Reel/Roll + Clip + 默认未配置”表。[RED Support Center](https://support.reddigitalcinema.com/hc/en-us)；[RED downloads](https://www.reddigitalcinema.com/downloads)

**按产品线结论**

| 产品线 | 卡内目录 | 素材命名 / Camera ID / Reel-Roll / Clip | 默认未配置命名 |
|---|---|---|---|
| DSMC / DSMC2 / RANGER | **未确认** | **未确认** | **未确认** |
| KOMODO / KOMODO-X | **未确认** | **未确认** | **未确认** |
| V-RAPTOR / V-RAPTOR XL | **未确认** | **未确认** | **未确认** |

`.RDC`、`.RDM`、`.R3D` 等观察值即使能帮助识别 RED 媒体，也不足以推出 `A001`。尤其当素材来自不同 RED 代际、固件或外部记录设备时，目录和命名可能不同。

### 2.9 DJI Ronin 4D

- DJI 官方 Ronin 4D 技术参数明确列出支持 `exFAT`，以及 DJI PROSSD 1TB、CFexpress 2.0 Type-B 和 USB-C SSD 等存储介质；这是卡/盘介质识别证据，不是命名协议。[DJI Ronin 4D specifications](https://www.dji.com/ronin-4d/specs)
- DJI 官方下载页提供版本化 Ronin 4D User Manual v1.4、PROSSD 使用说明等一手资料。[DJI Ronin 4D downloads](https://www.dji.com/ronin-4d/downloads)；[Ronin 4D User Manual v1.4 PDF](https://dl.djicdn.com/downloads/DJI_Ronin_4D/20231214/DJI_Ronin_4D_User_Manual_v1.4_en.pdf)
- 在本次检索到的 DJI 官方规格/下载资料中，未确认通用的 Camera ID、Reel/Roll、Clip 字段，也未确认 `A001_XXXX` 目录是 Ronin 4D 的厂商默认目录。上述字段、卡内目录和默认未配置命名均记为 **未确认**。

## 3. Nikon Z / ZR

### 3.1 Nikon ZR：官方明确的电影命名协议

Nikon ZR 是本文研究中最明确的一项。官方 Reference Guide 明确写出，打开 `[Video file naming] > [Video clip name]` 后，视频文件名适合多机拍摄/大量视频管理，并由以下部分构成：

1. **Camera ID**：相机 ID，可在 `[Camera ID]` 设置。
2. **Reel number**：为每张存储卡分配的卷号；若卡上已有视频文件名，沿用卡上的 Reel number；若没有，使用相机设置的 Reel number。
3. **Clip number**：以固定 `C` 开头的三位 Clip 编号；可使用连续编号模式。
4. **Month/Day**：开始录制的月/日。
5. **Random ID**：每个 Clip 自动生成、用于避免重复的随机 ID。

官方还明确了前提和目录：视频命名模式要求记录目标为 CFexpress/XQD 卡槽、卡为 exFAT、并开启 `Video clip name`；素材写入 `CLIPDATA` 文件夹下的 `CLIP` 文件夹。若关闭连续编号且卡上没有该类视频文件，Clip 序号从 `001` 开始。上述是 ZR 的官方规则，不应外推到所有 Nikon Z。[Nikon ZR Reference Guide - Video file naming](https://onlinemanual.nikonimglib.com/zr/en/09-04-51.html)

| 项目 | Nikon ZR |
|---|---|
| 卡内目录 | `CLIPDATA/CLIP`（仅在 Video file naming 模式及其前提满足时）。 |
| 素材命名 | Camera ID + Reel number + `C` + 三位 Clip number + Month/Day + Random ID。 |
| Camera ID | 官方确认，可配置。 |
| Reel/Roll | 官方确认；会受卡上已有视频命名文件影响。 |
| Clip | 官方确认；`C` 固定，三位编号，存在连续编号/起始编号设置。 |
| 默认未配置命名 | 仅能确认“Video clip name”关闭时不使用该专用模式；普通视频默认文件名的完整语法及空卡时的卷号：**未确认**。 |

### 3.2 Nikon Z9（代表性的 Nikon Z，不能代表全部 Z）

- Nikon Z9 官方 Reference Guide 对视频文件只确认 `[File Naming]` 用于选择三字母前缀，默认前缀是 `DSC`；该页面没有 Camera ID、Reel/Roll 或 Clip 的专用电影命名字段。[Nikon Z9 Reference Guide - Video Recording Menu / File Naming](https://onlinemanual.nikonimglib.com/z9/en/vrm_file_naming_129.html)
- 因此 Z9 的 Camera ID、Reel/Roll、电影 Clip 专用命名、专用 `CLIPDATA/CLIP` 目录和“未配置”默认命名：**未确认/不适用为 ZR 专用协议**。其他 Nikon Z 型号必须各查各自 Reference Guide；不能以 `A001_C018_...` 或 ZR 规则统一识别。

## 4. 官方 DIT 软件能力比较

以下只比较供应商自己的帮助中心、产品页或版本化手册。这里的“卷识别”指软件如何发现/登记挂载的卷或源，不等于软件能根据厂商文件名可靠推导 Camera ID。

| 能力 | Pomfort Silverstack | Imagine Products ShotPut Pro | YoYotta | Hedge OffShoot |
|---|---|---|---|---|
| 卡/卷识别 | Offload Menu 显示当前 mounted volumes，并区分 New、Previously used as Ingest Source、Other Volumes；支持从卷或文件夹选择源。[官方](https://kb.pomfort.com/silverstack/reference/library/offload-menu/) | 官方产品页确认面向 verified offloads；具体版本的媒体发现、卷登记和卡结构处理应以版本手册为准，公开页未确认一套跨版本 Camera ID 解析规则。[官方产品页](https://www.imagineproducts.com/product/shotput-pro)；[官方手册入口](https://www.imagineproducts.com/help/manuals) | 新相机卡/硬盘连接时弹出添加源面板；可只读挂载卡，加入 Job Table；卡卷和 Finder 中的源是明确工作对象。[官方](https://yoyotta.com/help/sources.html) | 以 disk/source 事件和 Ingest Browser 管理源；官方文档没有声称按 Sony/ARRI/RED 等型号统一解析 Camera ID。[官方](https://docs.hedge.video/offshoot/features/ingest-browser.md) |
| 模板/命名 | 支持 Offload 时文件重命名；卡名可进入 Bin/Reel/新文件名；支持保存工作流模板；Path Wildcards 可按元数据组成目的地和报告名。[官方](https://kb.pomfort.com/silverstack/hands-on/managing-data/file-renaming-on-offload/)；[官方](https://kb.pomfort.com/silverstack/reference/workflow-configuration/path-wildcards/) | 有版本化 Mac/Windows 手册入口，但本次公开页未核实具体重命名占位符；不应把 ShotPut 模板语法当作厂商相机命名规则。[官方](https://www.imagineproducts.com/help/manuals) | Destination path 使用项目、日期、volume、base 等 token；可保存 Preset；原始卡目录结构可继续保留。[官方](https://yoyotta.com/help/destinations.html) | `Auto Label`、`Rename Format`、`Folder Format` 分离；元素含 Source Name、Counter、Filename、日期等，Preset 可复用。[官方](https://docs.hedge.video/offshoot/features/organization.md) |
| 校验 | XXH64、Classic/ASC MHL、Verify activity、Checksum Creation；可组合在 Workflow 中。[官方](https://kb.pomfort.com/silverstack/getting-started/data-management/) | 官方产品页明确“verified offloads”；细节以当前版本手册为准。[官方](https://www.imagineproducts.com/product/shotput-pro) | Copy and verify；可输出 MD5、MHL 等报告；官方 Quick Start 明确“copied and verified”后生成报告。[官方](https://yoyotta.com/help/start.html)；[官方](https://yoyotta.com/help/destinations.html) | 所有 transfer 都校验；默认 Transfer Verification，可选 Source、Source & Destination；XXH64、MD5/SHA1/C4、ASC MHL。[官方](https://docs.hedge.video/offshoot/features/verification.md) |
| 报告 | Shooting day、Clips、Thumbnails、Contact print、Volume；支持 PDF/HTML，能手工或作为 workflow post-step 自动生成。[官方](https://kb.pomfort.com/silverstack/getting-started/reports/) | 产品页确认 PDF reports；具体报告字段/版本差异见官方手册。[官方](https://www.imagineproducts.com/product/shotput-pro)；[官方](https://www.imagineproducts.com/help/manuals) | PDF、ALE、CSV、MD5、MHL；报告可写本地和目的地，校验/拷贝有问题时不生成成功报告。[官方](https://yoyotta.com/help/destinations.html) | HTML/PDF Report；含 Source、Destination、clip/file、大小、checksum、各目的地状态及 transfer log 位置。[官方](https://docs.hedge.video/offshoot/features/reports.md) |
| 自动弹出 | Offload Menu 明确提供手动 eject；本次官方页面未确认“校验成功后自动弹出”。[官方](https://kb.pomfort.com/silverstack/reference/library/offload-menu/) | 本次公开官方资料未确认自动弹出策略。 | 官方页确认手动 eject；未称校验完成后必然自动 eject。[官方](https://yoyotta.com/help/sources.html) | 本次官方文档未确认通用自动 eject；Disk Removed 是事件，不等于软件主动弹出。[官方](https://docs.hedge.video/offshoot/features/automation/scripts/events/disk-removed.md) |
| 重连/恢复 | 本次审阅的官方页面确认卷状态分类和工作流 Job 管理，但未确认“同一卡卷重连后自动恢复”的统一行为。 | 本次公开资料未确认。 | 官方明确：弹出后再次连接的 drive 会自动回到 Job Table；点击 `-` 后下一次连接会被忽略；失败文件可从 Source Browser 移除后重跑。[官方](https://yoyotta.com/help/sources.html) | 支持 Stop/Resume/Failed/Completed with warnings；重连目的地前需清理不完整或零字节文件；可由 Disk Added/Disk Removed 等事件自动化。[官方](https://docs.hedge.video/offshoot/features/stop-and-resume.md)；[官方](https://docs.hedge.video/offshoot/features/automation/scripts/events/disk-removed.md) |
| 审计/追踪 | Silverstack Library、Jobs、Reports、MHL、原始 source 文件名记录，适合保留“原始名到目的地名”的链路。[官方](https://kb.pomfort.com/silverstack/hands-on/managing-data/file-renaming-on-offload/) | verified offload + PDF report 是官方确认的审计基础；字段级审计能力需按版本手册复核。[官方](https://www.imagineproducts.com/product/shotput-pro) | Project 的 SOURCE/COPY snapshots、PDF/MD5/MHL/CSV/ALE 报告和本地时间戳报告。[官方](https://yoyotta.com/help/projects.html)；[官方](https://yoyotta.com/help/destinations.html) | Transfer Logs、ASC MHL、校验日志、HTML/PDF reports；Report 可列出每个源、目的地、Clip/File、checksum 和状态。[官方](https://docs.hedge.video/offshoot/features/logging.md)；[官方](https://docs.hedge.video/offshoot/features/reports.md) |

### 4.1 对比较结果的解释

这些软件普遍把“相机原始目录/原始素材名”作为输入，再在**备份目的地**按模板组织或重命名。Silverstack 官方明确提醒：原始文件名仍可在 source 字段查到；这与直接改写卡卷卷标完全不同。[Silverstack file renaming on offload](https://kb.pomfort.com/silverstack/hands-on/managing-data/file-renaming-on-offload/)

因此，DIT Renamer 若只改 macOS volume label，不能宣称自己完成了素材文件重命名、目录重建、校验或备份审计。校验、报告、可恢复队列和来源链路应由上述专用工具承担，Swift 应避免把卷标操作包装成完整数据管理流程。

## 5. 本机 Silverstack Lab 只读样本

本机发现 Silverstack Lab 9 的应用数据位于 `~/Library/Application Support/Pomfort/SilverstackLab9`，包含多个 `Project-*/Project.plist` 和 `Silverstack.psdb` 项目库；设置数据库 `Settings.db` 是 SQLite `kvstore`，没有直接可用的公开媒体结构表。项目库正在使用时还可能有 `-wal`/`-shm` 文件，因此不应被工具直接打开、复制或写入。

只读扫描了 `~/Library/Logs/Silverstack Lab` 的日志，观察到以下脱敏后的真实样本线索：

- 同一日志集合同时出现 `M4ROOT`、`DCIM`、`PRIVATE`、`NIKON`、`ARRI`、`RED`、`CANON` 和 `SONY`。
- 片段名包含大量 `C001`、`C002` 等编号，也出现 `D001_F0300` 等其他结构。
- 一条拷贝任务呈现为 `01_OCF/C001RQ11/C001C015_YYMMDD_RQ11.mxf`，源卷和目标卷名称不同；这说明 Silverstack 项目中的交付目录/拷贝命名不能反推原始摄影机卡的卷名。
- 项目名本身是拍摄日期/项目名混合形式，不能当作摄影机卡卷名规则。

这些样本验证了当前实现的安全方向：只把完整扫描得到的原始卡目录作为证据；未识别或扫描截断时禁止自动命名。当前没有修改 Silverstack 的任何文件，也没有将素材路径、项目名或数据库内容写入仓库。

## 6. 对 Swift 1.1 的参考建议

以下是基于当前仓库代码的风险审阅，不是本文件对代码的修改。

### 6.1 不能用一个统一正则

当前 [`src_swift/MediaScanner.swift`](../src_swift/MediaScanner.swift) 将多种语义混在文件名正则里：

- 第 46-49 行把形如 `A001_XXXX` 的目录直接归为 DJI 候选；DJI 官方资料只确认存储介质/exFAT 和 User Manual 入口，未确认该目录是 Ronin 4D 厂商格式。[DJI specifications](https://www.dji.com/ronin-4d/specs)
- 第 151-165 行把首个 `C####.` 文件当成 Sony 未配置 Camera ID；`C####` 不是 Sony 独占证据，且 Sony FX3 官方可确认的是照片文件名前三字符，不是这个电影字段。[Sony FX3 Help Guide](https://helpguide.sony.net/ilc/2035/v1/en/print.html#TP1000283813)
- 第 167-184 行将 FX3/FX6/FX9/VENICE 合并成一条 `^([A-Z])(\d{3})[CR]\d{3}_` 规则；本次 Sony 一手资料没有支持把四个型号当成同一目录/命名协议，故不能称为 high confidence。[Sony professional camera resources](https://pro.sony/en_GB/products/digital-cinema-cameras)
- 第 187-215 行把 Nikon ZR 的日期后两个随机字符写死为 `[A-Z0-9]{2}`；官方 ZR 只定义该部分为 Random ID，并且 Camera ID、Reel number、Clip number 都是可设置/受卡上内容影响的字段。正则可以是观察提示，不能代替 Nikon 的条件检查。[Nikon ZR Video file naming](https://onlinemanual.nikonimglib.com/zr/en/09-04-51.html)
- 第 218-237 行曾在 RED 文件名不匹配时把 Camera/roll 默认成 `A`/`001`；1.1 已改为没有 Camera/Reel 证据时返回空建议。RED 官方按产品线提供资料，没有一份可支持所有型号/固件的默认 `A001` 结论。[RED Support](https://support.reddigitalcinema.com/hc/en-us)
- 第 240-260 行把 ARRI、Canon 和其他素材归为 `standardCinemaRegex`；ARRI 的命名模型与 Canon Cinema EOS 不能合并，Canon 的型号/固件资料也没有在本次公开门户中确认同一语法。[ARRI Technical Downloads](https://www.arri.com/en/learn-help/learn-help-camera-system/technical-downloads)；[Canon manual portal](https://cam.start.canon/en/)

### 6.2 不能默认自动重命名为 A001

当前 [`MediaScanner.swift`](../src_swift/MediaScanner.swift) 的未知媒体 fallback 返回 `suggestedName: nil`；1.1 移除了原先的 `A001` 占位值，因为它不是任何已核实厂商的通用默认值。仍需防止各厂商分支在缺少 Camera/Reel 证据时自行填入 `A001`。其风险包括：

1. **误写来源事实**：未知厂商、空目录、外录素材、照片卡、损坏/未完成拷贝和普通数据盘都可能落入 fallback；`A001` 会把“未知”伪装成已识别的 Camera A / Reel 001。
2. **跨机型碰撞**：不同相机、不同卡、不同机位都可能被写成同一个卷标。Silverstack、YoYotta 和 OffShoot 的官方工作流都依赖 source/volume、文件路径、校验日志或 project snapshot 保持来源区分，而不是让未知源共享一个编号。[Silverstack data management](https://kb.pomfort.com/silverstack/getting-started/data-management/)；[YoYotta projects](https://yoyotta.com/help/projects.html)；[OffShoot reports](https://docs.hedge.video/offshoot/features/reports.md)
3. **破坏人工复核信号**：研究结论“未确认”应在 UI 和审计中保留。自动命名条件至少应要求厂商/型号证据、完整目录结构、多个素材一致性、命名开关状态、卷号/Clip 关系和人工确认；仅首个排序文件匹配不能满足这些条件。
4. **不能把卷标和素材名混为一谈**：`RenamerEngine` 只执行 macOS `diskutil rename` 并在同一 BSD/UUID 上复核；它没有修改卡内素材文件名、目录、MHL/checksum 或备份报告。即使 volume label 成功，原始媒体仍保持原厂名。

### 6.3 建议的安全数据模型（仅建议，不是规则）

- 把结果拆成 `vendor`, `model`, `firmwareEvidence`, `mediaType`, `filesystem`, `directoryEvidence`, `clipEvidence`, `cameraID`, `reelNumber`, `clipNumber`, `confidence`, `needsReview`；字段缺失使用 `nil`/“未确认”，不要填 `A001`。
- 先做只读目录快照和文件名样本，再按**型号+固件+记录模式**选择解析器。一个解析器只负责一个厂商定义的证据，不要用“Cinema Card”通用分支冒充型号识别。
- 对 Nikon ZR，应先验证 exFAT、CFexpress/XQD 槽位、`CLIPDATA/CLIP`、命名开关以及 Camera ID/Reel/Clip 的一致性；对其他 Nikon Z 不得自动套用 ZR。
- 对 ARRI/RED/Sony/Canon/DJI，若没有对应官方章节或明确目录证据，返回“可观察到模式，但未确认”，默认保持原卷标并要求人工输入。自动操作的门槛应高于 UI 展示模式的门槛。
- 将“建议目的地模板”与“相机原始命名解析”分离。目的地模板可以使用项目、日期、人工输入的 camera/reel 等字段，但不能把模板生成值反写为相机事实。
- 审计记录至少保留原卷标、BSD node/volume UUID、扫描时间、文件系统、目录证据、首尾样本、用户确认、请求名、实际名、成功/失败信息。校验和多副本报告仍交给 Silverstack/ShotPut Pro/YoYotta/OffShoot 等专用工具。

## 7. 资料缺口与后续核对清单

1. Sony FX6、FX9、VENICE：需要具体型号、固件版本和官方 Operating Instructions 中的卡内目录/文件命名章节；当前公开 Sony 产品页不足以确认 Camera ID/Reel/Clip。
2. Canon Cinema EOS：需要 C70、C300 Mark III、C500 Mark II、C400、C80 等每个目标型号的地区版/固件版官方手册；当前 Canon 门户需要地区选择，公开产品页不提供完整命名字段。
3. ARRI：需要 ALEXA 35、ALEXA LF、ALEXA Mini LF、AMIRA 各自固件版本的 User Manual 对照表，特别是默认 Camera Index/Reel、换卡继承和不同 codec 的目录树。
4. RED：需要按 DSMC/DSMC2/RANGER、KOMODO/KOMODO-X、V-RAPTOR/V-RAPTOR XL 分别取官方手册，核对 `.RDC`/`.RDM` 目录、R3D 文件名和相机设置的 ID/卷号关系；当前 RED Support 的产品线分类不能推出统一规则。
5. DJI Ronin 4D：需要官方 User Manual v1.4 的存储目录/文件名章节和不同 PROSSD、CFexpress、USB-C SSD、ProRes/H.264/RAW 组合的样卡证据；当前规格页未确认 Camera ID/Reel/Clip。
6. Nikon Z：需要明确 Swift 1.1 要支持的具体 Z 型号。Z9 的官方规则是三字母 `DSC` 文件名前缀，ZR 是单独的 Video file naming 协议；不能用一个 Nikon Z 解析器覆盖全部型号。
7. ShotPut Pro：需要当前部署的 Mac/Windows 版本手册全文，逐项确认卡卷重连、自动弹出、模板 token、报告字段和审计日志语义。官方公开页目前只足以确认 verified offloads、PDF reports 和版本化手册入口。
8. Silverstack、YoYotta、OffShoot：需要锁定项目实际使用版本后再核对功能开关名称；官方文档会随版本更新，尤其是 OffShoot Reports 的版本要求和 Silverstack 的 workflow/report UI。

## 8. 主要官方来源索引

- Sony FX3 Help Guide: <https://helpguide.sony.net/ilc/2035/v1/en/print.html>
- Sony Professional cameras: <https://pro.sony/en_GB/products/digital-cinema-cameras>
- Canon manual portal: <https://cam.start.canon/en/>
- Canon EOS C70: <https://www.usa.canon.com/shop/p/eos-c70>
- ARRI ALEXA Mini LF and downloads: <https://www.arri.com/en/cine-systems/cine-cameras/alexa-mini-lf>
- ARRI Technical Downloads: <https://www.arri.com/en/learn-help/learn-help-camera-system/technical-downloads>
- RED Support: <https://support.reddigitalcinema.com/hc/en-us>
- DJI Ronin 4D Downloads: <https://www.dji.com/ronin-4d/downloads>
- DJI Ronin 4D Specifications: <https://www.dji.com/ronin-4d/specs>
- Nikon ZR Reference Guide: <https://onlinemanual.nikonimglib.com/zr/en/09-04-51.html>
- Nikon Z9 Reference Guide: <https://onlinemanual.nikonimglib.com/z9/en/vrm_file_naming_129.html>
- Pomfort Silverstack Knowledge Base: <https://kb.pomfort.com/silverstack/>
- Imagine Products ShotPut Pro: <https://www.imagineproducts.com/product/shotput-pro>
- Imagine Products manuals: <https://www.imagineproducts.com/help/manuals>
- YoYotta Quick Start: <https://yoyotta.com/help/start.html>
- YoYotta Sources: <https://yoyotta.com/help/sources.html>
- YoYotta Destinations and Reports: <https://yoyotta.com/help/destinations.html>
- Hedge OffShoot documentation index: <https://docs.hedge.video/llms.txt>
- Hedge OffShoot Verification: <https://docs.hedge.video/offshoot/features/verification.md>
- Hedge OffShoot Organization: <https://docs.hedge.video/offshoot/features/organization.md>
- Hedge OffShoot Reports: <https://docs.hedge.video/offshoot/features/reports.md>
- Hedge OffShoot Stop & Resume: <https://docs.hedge.video/offshoot/features/stop-and-resume.md>

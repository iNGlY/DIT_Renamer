# 摄影机媒体命名与 DIT 软件参考

更新日期：2026-08-10

本文整理 DIT Renamer 1.1 所依据的厂商资料和现场边界。结论只用于只读识别和卷名建议，不授权软件修改卡内目录、素材文件名、Camera ID、Reel/Roll 或 Clip 编号。

## 如何使用这些资料

卡内目录、素材名、Camera ID、Reel/Roll、Clip 和卷名是不同信息。厂商手册只说明其中一项时，不能把它扩展成完整的命名规则。

DIT Renamer 采用以下边界：

- 文件名模式只作为线索，不单独证明厂商或机型。
- 型号、固件或记录模式不明确时，不自动套用其他型号的规则。
- 缺少 Camera ID 或 Reel 证据时，不用 `A001` 填补空值。
- 卷名建议需要操作员确认；修改卷名不会改变卡内素材。

## 厂商资料

### Sony FX3、FX6、FX9 与 VENICE

Sony FX3 官方 Help Guide 明确说明了照片文件的三字符前缀、照片文件夹和可用存储卡，但没有在该章节定义电影素材的 Camera ID、Reel/Roll 或 Clip 语法。`C0001` 不能单独识别 FX3。

FX6、FX9 和 VENICE 的公开产品页可以确认型号和产品线，却不足以确定不同固件、记录格式下的完整目录和素材命名。具体型号识别应优先读取卡内 XML/XMP 明确给出的型号；只有元数据不足时，才可选择用 exiftool 检查一条代表性素材。

现场已确认 FX3 和 FX6 可能把卡卷命名为 `Untitled`。这是操作经验，不应写成所有 Sony 型号和固件都适用的厂商规则。名为 `Untitled` 的备份盘不在 DIT Renamer 的处理范围内。

来源：[Sony FX3 Help Guide](https://helpguide.sony.net/ilc/2035/v1/en/print.html)、[Sony FX6](https://pro.sony/en_GB/products/handheld-camcorders/ilme-fx6)、[Sony Cinema Line](https://pro.sony/en_GB/products/digital-cinema-cameras)。

### Canon Cinema EOS

Canon 的公开产品页和手册入口不能证明 C70、C300 Mark III、C500 Mark II、C400、C80 等型号共享同一套 Camera ID、Reel/Roll 或 Clip 规则。实现时应按具体型号和固件读取手册；没有对应证据时只显示可观察到的模式，不自动命名。

来源：[Canon 相机手册入口](https://cam.start.canon/en/)、[Canon EOS C70](https://www.usa.canon.com/shop/p/eos-c70)。

### ARRI ALEXA 与 AMIRA

ARRI 的素材命名通常涉及 Camera Index、Reel counter、Clip counter、日期和唯一字段，但 ALEXA 35、ALEXA LF、ALEXA Mini LF、ALEXA Mini、ALEXA 65 与 AMIRA 的手册和固件不能互换。文件名中的 Camera/Reel 信息也不等于 macOS volume label。

DIT Renamer 可以把明确的 ARRI 目录和素材模式作为识别线索，但自动规则必须绑定到具体产品和记录格式。HDE 容量功能只给出参考估算，不调用编码器，也不保证最终容量。

来源：[ARRI Technical Downloads](https://www.arri.com/en/learn-help/learn-help-camera-system/technical-downloads)、[ALEXA Mini LF](https://www.arri.com/en/cine-systems/cine-cameras/alexa-mini-lf)、[AMIRA](https://www.arri.com/en/cine-systems/cine-cameras/amira)。

### RED Digital Cinema

RED 按 DSMC、DSMC2/RANGER、KOMODO/KOMODO-X、V-RAPTOR/V-RAPTOR XL 等产品线分别提供资料。`.RDC`、`.RDM` 和 `.R3D` 可以帮助识别 RED 媒体，但不足以从所有型号和固件中推出同一个 Camera/Reel 规则，更不能在没有证据时默认 `A001`。

来源：[RED Support](https://support.reddigitalcinema.com/hc/en-us)、[RED Downloads](https://www.reddigitalcinema.com/downloads)。

### DJI Ronin 4D

DJI 官方资料确认 Ronin 4D 支持 exFAT，以及 PROSSD、CFexpress Type B 和 USB-C SSD 等存储介质。公开规格和下载页没有定义一套通用的 Camera ID、Reel/Roll、Clip 或 `A001_XXXX` 目录规则。

用户提供的 DJI 样卡结构可用于测试目录扫描，但样卡只能证明该设备、固件和记录设置下的实际结果，不能替代厂商规则。扫描器应同时检查目录、扩展名和多条素材的一致性。

来源：[DJI Ronin 4D Specifications](https://www.dji.com/ronin-4d/specs)、[Ronin 4D Downloads](https://www.dji.com/ronin-4d/downloads)、[Ronin 4D User Manual v1.4](https://dl.djicdn.com/downloads/DJI_Ronin_4D/20231214/DJI_Ronin_4D_User_Manual_v1.4_en.pdf)。

### Nikon ZR 与其他 Nikon Z

Nikon ZR 的官方 Reference Guide 给出了明确的视频命名模式：Camera ID、Reel number、以 `C` 开头的三位 Clip number、月/日和 Random ID。该模式要求使用指定卡槽、exFAT，并开启 `Video clip name`；素材位于 `CLIPDATA/CLIP`。

这套规则不能扩展到所有 Nikon Z。以 Z9 为例，公开手册只确认可设置三字符文件名前缀，默认值为 `DSC`，并没有提供 ZR 的专用电影命名协议。

来源：[Nikon ZR Video File Naming](https://onlinemanual.nikonimglib.com/zr/en/09-04-51.html)、[Nikon Z9 File Naming](https://onlinemanual.nikonimglib.com/z9/en/vrm_file_naming_129.html)。

## 同类软件可以提供什么

| 软件 | 适合参考的能力 | 与 DIT Renamer 的区别 |
| --- | --- | --- |
| Pomfort Silverstack | Offload 工作流、路径模板、校验、报告和素材库追踪 | 管理拷贝和素材链路；DIT Renamer 只处理拷贝前的卷名 |
| ShotPut Pro | Verified offload 和 PDF 报告 | 不应把备份模板当作摄影机原始命名规则 |
| YoYotta | Source/Job 管理、目的地 token、校验和报告 | 管理源和多个目的地，并保留项目快照 |
| Hedge OffShoot | Auto Label、Rename/Folder Format、校验、报告和传输日志 | 组织备份和传输，不证明摄影机型号或卷号 |

这些工具普遍把摄影机卡的原始目录和素材名作为输入，再在备份目的地按模板组织数据。目的地模板可以使用项目、日期、机位或卷号，但模板生成的值不能反写成相机事实。

来源：[Silverstack](https://kb.pomfort.com/silverstack/)、[ShotPut Pro](https://www.imagineproducts.com/product/shotput-pro)、[YoYotta](https://yoyotta.com/help/start.html)、[OffShoot](https://docs.hedge.video/offshoot/features/ingest-browser.md)。

## 现场样本带来的结论

对匿名化 Silverstack Lab 日志和用户提供的卡结构做只读检查后，可以确认：同一项目中可能同时出现 Sony、ARRI、RED、Canon、Nikon 和 DJI 风格的目录；备份目的地的项目名、Bin 名和文件夹名也可能与原卡卷名完全不同。

因此，实现应坚持以下原则：

- 只把完整扫描得到的原始卡目录和素材作为识别证据。
- 扫描被截断、目录混杂或素材范围不一致时，停止自动命名。
- 重复 UUID 只有在首末素材与上次记录不同、且设备身份复核通过时，才允许继续自动流程。
- 审计记录保存原卷名、新卷名、BSD 节点、UUID、素材范围、扫描时间和结果。
- 拷贝校验、MHL、多个备份目的地和恢复队列继续交给 Silverstack、ShotPut Pro、YoYotta 或 OffShoot。

## 尚需按型号补充的资料

- Sony FX6、FX9 和 VENICE 的具体固件手册及媒体命名章节
- Canon C70、C300 Mark III、C500 Mark II、C400 和 C80 的型号/固件规则
- ARRI 各机型、codec 和固件对应的目录与后缀差异
- RED 各产品线的 `.RDC`、`.RDM` 和 R3D 命名关系
- DJI Ronin 4D 在不同介质与编码组合下的官方目录说明
- 项目实际部署版本中的 Silverstack、ShotPut Pro、YoYotta 和 OffShoot 功能名称

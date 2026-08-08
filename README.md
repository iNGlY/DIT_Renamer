# DIT Renamer (现场卡卷重命名与自动化助手 - V0.2 开源专业版)

**DIT Renamer** 是一套专为影视 DIT（数字影像技术员）、数据现场工程师及助理开发的高度定制化卡卷管理、智能重命名与安全防护桌面端系统。

本软件结合了真实片场苛刻工况下的无数实战经验（包括克服 APFS 空间管理器损坏、闪迪 4T 掉盘门避坑、优化 Sony FX 及主流设备命名推断），旨在建立一套**零误触、全自动、绝对可溯源**的现场卡卷处理流水线。

---

## 🌟 核心功能亮点

### 1. ⚡ 极速冷启动与无感状态记忆
- 彻底剔除底层串口诊断等沉重开销，采用原生本地 Webview 渲染，macOS 现场打开响应时间缩短至毫秒级。
- 本地 `localStorage` 自动持久化记忆所有忽略设备清单与自动重命名开关状态，下次开机即用。

### 2. 🛡️ 智能卡盘分流与 APFS 硬件级防护
- **精准识别**：自动探测 SONY (M4ROOT)、DJI (DCIM)、CANON、ARRI 等主流摄像机储存卡文件特征。
- **硬核安全红线**：对于非相机卡（外接移动 SSD、RAID 阵列、交付盘），程序静默识别为“被忽略的设备”或普通外接卷，**禁止默认自动读写其敏感文件表结构**，彻底避免因为高频扫描触发类似闪迪 4T SSD 掉盘导致的“APFS 空间管理器 (Spaceman) 校验和破裂”等毁灭性灾难。

### 3. 🔄 插卡无感全自动重命名 (V0.2 特色)
- 在左侧侧边栏开启“⚡ 全自动重命名”开关后，系统在后台轮询新装载设备。
- 探测到未命名的相机原始卡插入时，智能解析设备与 Clip 编号结构（精准识别 Sony Cam ID+Reel# 及消除 C 前缀误判），自动推断递增卡号（例如自动推断前序为 A001，将当前卡分配为 `A002`），执行底层重命名。
- **插卡即拔卡**：如果推断规则出现歧义，软件会自动中止并亮起黄色警示，等待人工介入确认，保障万无一失。

---

## 📚 现场 DIT 必备技术手册库 (`docs/`)

为规范现场作业标准，本项目内置了三套珍贵的实战业务指南（见 `docs/` 目录）：
1. **[《Pomfort Silverstack 路径管理与 Relink 重新链接标准手册》](docs/silverstack_relink_guide.md)**
   - 详解为什么绝对不能在拷贝完后在访达直接改名。
   - 遇到特殊情况如何使用 Relink Wizard（重新链接向导）无损替换路径并重新验证 XXHash/MD5。
   - 如何使用 Path Wildcards（路径通配符）实现卸载前置自动化命名。
2. **[《现场 SSD 无法识别与 APFS 底层损坏急救指南》](docs/apfs_emergency_recovery.md)**
   - 遭遇 `failed to read spaceman cib` 错误时的急救红线（严禁跑“急救”和格式化）。
   - 如何通过命令行进行强制只读挂载 (`sudo diskutil mount readOnly`) 抢救数据。
   - 如何使用底层软件 (Disk Drill / UFS Explorer) 绕过系统提取 RAW 数据及对客户交底的专业话术。
3. **[《硬件选购、跨平台存储与 DIT 运维实战手册》](docs/hardware_dit_knowledge_base.md)**
   - 40G/10G 硬盘盒（ASM2464PD vs JHL7440）、手机 MagSafe 磁吸 NVMe 盘防掉盘与屏幕热损伤防范。
   - 跨平台 (Mac/iOS/Android/Win) exFAT GPT 格式化与 128KB 簇大小防 RAW 避坑。
   - Apple Silicon (M3 Pro) Ventoy 部署与 RTL9210 物理掉盘排障、950G exFAT 无损/跨平台切分规范。
   - Kali Linux 虚拟机性能与鼠标优化、外置无线渗透网卡 (MT7612U/MT7921AUM vs Realtek 黑名单) 选型全解及 smartctl/DiskMoni 系统级修复。

---

## 🛠️ 项目结构

```text
DIT_Renamer/
├── .agents/                # AI Agent 技能配置 (Workspace Skills)
│   └── skills/
│       └── hardware-dit-knowledge-base/   # 硬件与 DIT 运维技能包
├── src/                    # 源代码
│   ├── app.py              # PyWebView 桌面端主程序
│   └── web/                # 前端 UI 与控制器
│       └── index.html      # 界面代码与本地化脚本
├── docs/                   # 现场业务、硬件与急救技术规范
│   ├── silverstack_relink_guide.md
│   ├── apfs_emergency_recovery.md
│   └── hardware_dit_knowledge_base.md
├── scripts/                # 自动化构建工具链
│   └── build_macos_app.sh  # macOS 一键编译打包导出脚本
├── requirements.txt        # 依赖包清单
└── README.md               # 项目使用说明书
```

---

## 🚀 快速开发与编译

### 1. 本地直接运行 (开发调试模式)
```bash
# 激活 Python 虚拟环境 (或安装依赖)
pip install -r requirements.txt

# 启动应用程序
python src/app.py
```

### 2. 一键编译并导出 macOS .app / .zip (交付模式)
我们内置了全自动化编译脚本，执行后将调用 PyInstaller 生成本地二进制应用程序，并自动将其无缝复制、打包至您的 **系统下载文件夹 (`~/Downloads`)**：
```bash
# 执行打包脚本
./scripts/build_macos_app.sh
```
编译完成后，前往 `~/Downloads/dit_renamer_V0.2.app` 即可双击打开使用！

---
*版权所有 (c) 2026 DIT Renamer Team. 专为极致现场数据交付体验而生。*

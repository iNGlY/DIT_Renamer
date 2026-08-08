# 硬件选购、跨平台存储与 DIT 运维实战手册

本文档归档整理了关于 40Gbps 硬盘盒、磁吸硬盘盒、MacBook 拓展坞选购、exFAT/APFS/NTFS 跨平台文件系统格式化规范、PE/Kali Linux 多系统引导分区、笔记本物理磁吸/屏幕热损伤案例防范及 Pomfort Silverstack DIT 关键界面的完整实战指南。

---

## 一、 40Gbps & 10Gbps 硬盘盒与拓展坞选购

### 1. 40Gbps 主控芯片对比
* **ASMedia ASM2464PD**：USB4/雷电4 方案，实测读写 `3100-3300 MB/s`，向下兼容 USB 3.2 Gen2x2，性价比高，但**发热巨大，高负载需主动散热**。
* **Intel JHL7440 / JHL8440**：雷电3/4 方案，实测读写约 `2800 MB/s`，Mac 兼容性极佳，发热相对温和，但不支持 20G 协议，价格较贵。

### 2. 磁吸 2230 手机硬盘盒选购
| 型号 | 价格 | 主控 | 散热设计 | 稳定性/特点 |
| :--- | :--- | :--- | :--- | :--- |
| **海备思 MC100 Pro** | ￥220 - 260 | RTL9210B | 铝合金被动 | **带超级电容断电保护** + 支持 PD100W 边充边录，掉盘率极低。 |
| **闪极 Disk 磁吸版** | ￥260 - 340 | RTL9210B | **内置静音风扇** | 主动风扇压制温度，长时间 4K ProRes 录制不掉速。 |
| **阿卡西斯 磁吸 2230**| ￥130 - 170 | RTL9210B | 立体鳍片铝壳 | 做工扎实，温控良好。 |
| **佳翼 Z7 磁吸版** | ￥80 - 120 | RTL9210B | CNC 铝马甲 | 性价比极高，需搭配低功耗盘。 |

> **防掉盘 SSD 搭配**：推荐低功耗 2230 盘（如海力士 BC711/BC901、铠侠 BG5/BG6、西数 SN740），避开三星 980Pro/990Pro 等高功耗旗舰盘。

### 3. 无源 4口 10Gbps HUB 物理原理
* **供电上限**：MacBook 电脑 C 口无源输出功率极限为 `5V/3A (15W)`。
* **物理限制**：单口或小功耗设备（U盘/键鼠）可无源跑满；但**无法同时驱动 4 个高功耗 NVMe 移动固态硬盘**（总功耗超 15W 会触发电脑保护）。

### 4. PD 供电 USB4 (40Gbps) 拓展坞
* 解决传统雷电 4 拓展坞依赖笨重 DC 砖头电源的痛点。
* 拓展坞带 **100W PD C口输入**，只需自备 100W 氮化镓充电头，扣除拓展坞自身约 15W 功耗后，可反向给 MacBook Pro 提供 85W 充电。推荐：**Satechi USB4 Multiport**、**阿卡西斯 USB4 100W PD 版**。

---

## 二、 跨平台文件系统格式化指南 (Mac / iPhone / Pixel 10 Pro / Win7)

### 1. 三端原生兼容最佳方案：`exFAT` + `GUID 分区图 (GPT)`
* **兼容性**：Mac、iPhone (iOS 文件 App)、Pixel 10 Pro (Android 13+ 原生) 均能原生完全读写，无单文件 4GB 限制。
* **MC100Pro 加持**：海备思内置超级电容补偿了 exFAT 缺乏“日志断电恢复”的软肋。

### 2. 双分区方案 (exFAT + APFS/NTFS) 隔离安全
* **结构**：分区一 `exFAT` (500G) + 分区二 `APFS` 或 `NTFS` (剩余空间)。
* **安全原理解析**：
  * GPT 分区表在物理扇区上完全隔离，exFAT 的读写越界不了 APFS/NTFS。
  * Android 连接时，会自动忽略 APFS 分区（由于缺乏驱动），**零损坏风险**。
  * 若 Pixel 已 Root，可通过 Magisk/KernelSU 模块挂载 NTFS 分区。

### 3. 避免 Windows 读不到 exFAT 的关键设置
* **簇大小 (Cluster Size)**：Mac 格式化 exFAT 时容易将簇大小设得太大（如 >1024KB），超出 Windows 驱动上限显示为 RAW。**解决对策**：在 Windows 上进行格式化，分配单元大小手动指定为 **128 KB**。
* **物理安全**：Win7 弹出“需要格式化”提示时**必须点取消**。

---

## 三、 2026 最强 PE & Kali Linux 多系统引导规划

### 1. 2026 最强 PE 推荐
* **优启通 (EasyU)**：运维天花板，最新 NVMe/RAID/服务器卡/网卡驱动覆盖第一。
* **微 PE (WePE)**：极简纯净，零广告。
* **Edgeless (无边 PE)**：支持热加载模块、支持显卡渲染与联网/远程协助。
* **Sergei Strelec PE**：国外核武库级维护/解密/取证 PE。

### 2. Ventoy 多系统引导 + Kali Persistence (持久化) 物理分区
* **分区 1 (exFAT)**：主数据区，放置 `EasyU.iso`、`WePE.iso`、`kali-linux-live.iso`。
* **分区 2 (FAT)**：Ventoy 引导区 (自动生成 32MB)。
* **分区 3 (ext4)**：**卷标设置为 `persistence`**。根目录新建 `persistence.conf` 写写入 `/ union`。可在 Kali Live 中永久保存工具和修改。

---

## 四、 笔记本磁吸物理影响与屏幕热损伤案例

### 1. 吸在 C 面掌托/触控板旁 的危害
* **误触发霍尔传感器 (Hall Sensor)**：导致电脑频繁黑屏并误入休眠。
* **干扰扬声器与磁悬浮风扇**：强磁场偏置音圈与风扇轴承，引起异响或失真。
* **划伤铝合金 C 面外壳**。

### 2. 吸在 A 面屏幕背板 的物理发热伤害案例
* **物理危害**：海备思 MC100Pro 高速写入时温度高达 **50°C - 65°C**。贴在仅 1-2mm 厚的 A 面，局部热量直传屏幕背板。
* **案例来源**：Reddit (r/macbookpro)、Apple Support Communities、iFixit 拆解报告。
* **损毁机制**：
  1. **背光扩散膜 (Diffuser Sheet) 热氧化黄化**（产生不可逆黄色暗斑，截图看不出来，肉眼清晰可见）；
  2. **OCA 光学胶热变性融化**；
  3. **液晶分子相变退化**；
  4. **屏幕转轴杠杆受力变松**。
* **最佳使用姿势**：**桌面平放 + 10cm 短线连接**。

---

## 五、 Silverstack / Silverstack Lab DIT 软件界面对照

### 1. Copy&Jobs (拷贝与任务)
* `Parallel Workflows, Jobs and Tasks`: 并行工作流与任务
* `Show Volume Details`: 显示存储盘详情
* `Default Max Reading for New Sources: 1 (Sequential Reading, Recommended)`: 新源盘默认最大读取数（1 顺序读取）
* `Read Buffer Size: 8 MB`: 读取缓冲区大小 8MB
* `Hash Manifest: ASC MHL`: 哈希校验清单（ASC MHL 标准）
* `GPU Selection: Manual (Apple M3 Pro)`: 手动指定 GPU 加速

### 2. General (常规设置)
* `Hide verification state indicator for bins`: 在素材箱隐藏校验状态指示器
* `Decimal Places for File Size Values: 2`: 文件大小保留 2 位小数
* `Warn me about unread failed jobs on every new workflow`: 新工作流提醒未读失败任务

### 3. External Video (外部视频输出)
* `Enable external video output`: 启用外部视频输出
* `Level: Legal Range`: 信号电平范围（视频合法电平 16-235）
* `RGB-YCbCr Conversion: Rec.709 Matrix`: Rec.709 转换矩阵
* `Release Blackmagic devices when Silverstack is in background`: 后台运行时释放 BMD 设备

---

## 六、 Apple Silicon (M3 Pro) 下 Ventoy 部署与物理卡死全排障

### 1. 终端报错 `cannot execute binary file` 的底层机制
* **核心原因**：Ventoy 官方 Linux 压缩包里的 `aarch64/V2DServer` 等底层程序是为 **Linux (ARM64 ELF 格式)** 编译的。macOS 的 Darwin 内核无法直接运行 ELF 二进制文件。

### 2. Realtek RTL9210 移动硬盘盒 + Linux 虚拟机 (VMware/UTM) 掉盘死锁
* **现象与报错**：`I/O error, dev sda, sector 128` 或 `Timed out while waiting for udev queue to empty`。
* **物理机制**：RTL9210 芯片的 **UASP (USB Attached SCSI)** 协议与 Linux 内核 `uas` 驱动在虚拟机 USB 直通层触发协议死锁，导致物理 NVMe 盘被保护性断电掉盘。
* **规避/临时解法**：
  * 尽可能**避免在虚拟机里直通 NVMe 移动硬盘盒进行写盘**。
  * 必须在 Linux 里写盘时，运行 `sudo udevadm control --stop-exec-queue` 临时暂停 udev 监听，写完再开启；或者运行 `sudo modprobe -r uas` 降级为普通 `usb-storage` 模式。

### 3. M3 Pro 上部署 Ventoy 的零报错极速方案
1. **方案一：WinPE 物理原生写入（最推荐/0 报错）**：进入 WinPE（微 PE / Strelec PE），运行 `Ventoy2Disk.exe`，选用 **GPT 架构**，预留 950G 空间。利用 Windows 原生 `USBSTOR.sys` 驱动写入，5 秒搞定且永远无错。
2. **方案二：macOS 纯原生 `dd` 命令写入**：解压 Ventoy Linux 包，进入 `boot` 目录，卸载磁盘 `diskutil unmountDisk /dev/diskX`，运行 `sudo dd if=boot.img of=/dev/rdiskX bs=1m`，使用 macOS 原生驱动直接将官方引导打入底层，完全不经过 Linux 内核。
3. **方案三：社区 macOS 原生 GUI 工具 `MacToy`**。

### 4. Ventoy 成功部署的三步验证法
1. **静态检查**：Mac 上运行 `diskutil list`，物理盘下必须包含一个约 **32MB** 的隐藏引导分区 **`VTOYEFI`** (FAT16)。
2. **软件检测**：Linux 下运行 `sudo ./Ventoy2Disk.sh -c /dev/sdX` 或 `VentoyWeb.sh`，界面明确显示 `Ventoy In Device` 具体版本。
3. **真实引导**：把 `.iso` 镜像拖入主 exFAT 数据区，电脑开机按 `F12` 或 `Option` 选择该盘启动，能弹出 Ventoy 经典蓝底黑框菜单。

---

## 七、 跨平台 950GB 无损/最大兼容空间拆分规范

### 1. 三端（Mac M3 Pro / Windows / iPhone iOS 13+）最大兼容性三大要素
* **GPT (GUID 分区表)**：苹果与 Windows 共同的现代标准架构。
* **exFAT 文件系统**：四大平台官方唯一原生免驱支持读写的文件系统。
* **128 KB 簇大小 (Cluster Size)**：防掉盘、防文件目录损坏、兼顾读写性能的最佳簇尺寸。

### 2. macOS 对 exFAT 拆分的局限性与避坑
* **限制**：macOS 自带 `diskutil` 引擎**不支持对 exFAT 进行在线无损缩小 (`resizeVolume`)**。
* **禁用 APFS**：切分新分区时严禁选择 APFS，否则 Windows 和 iPhone 将完全无法读写。
* **macOS 原生拆分命令**：`diskutil partitionDisk diskX GPT ExFAT Ventoy 40G ExFAT DATA 0b`（将前部 40G 留给 Ventoy ISO，尾部 950G 划给 DATA）。

### 3. Linux (Kali) 下无损 Resize 开源工具：GParted
* **实现**：借助最新 **`exfatprogs`** 开源库，Linux 上的 **GParted** 能够对 exFAT 进行安全的无损拖动调整大小 (Resize)。
* **报错 `gpartedbin is already running`**：运行 `sudo pkill -9 gpartedbin` 强制杀死后台僵尸进程后重新打开。

---

## 八、 Kali Linux 运维初始化与排障指南

### 1. VMware / UTM 性能与流畅度极速优化
* **硬件分配**：分配 **4 核 CPU** + **4GB/8GB 内存**。
* **显卡 3D 加速**：勾选 `3D Graphics Acceleration` / `virtio-ramfb-gl`（GPU 加速是消除界面卡顿的核心）。
* **安装官方增强驱动**：运行 `sudo apt update && sudo apt install -y open-vm-tools-desktop spice-vdagent`，重启后解决分辨率自适应与平滑鼠标。
* **关闭 XFCE 桌面特效**：`Settings` -> `Window Manager Tweaks` -> `Compositing` -> 取消勾选 `Enable display compositing`。

### 2. 虚拟机鼠标丢失应急找回
* 按 **`Control + Option`** 或 **`Control + Command`** 强行释放/捕获鼠标。
* 键盘按 `Ctrl + Alt + T` 调出终端，运行 `sudo systemctl restart lightdm` 重启桌面。

### 3. Linux 下 Shell 脚本 (.sh) 规范运行
* 免权限运行：`sudo bash 脚本名.sh`
* 赋予权限运行：`chmod +x 脚本名.sh && sudo ./脚本名.sh`

### 4. USB 直通后无法识别多分区的强制刷新
* **刷新命令**：在 Kali 终端运行 `sudo partprobe /dev/sdX` 或 `sudo blockdev --rereadpt /dev/sdX` 强制内核重新扫描磁盘分区表。

### 5. Linux 下 APFS 读取与 GParted 限制
* **只读挂载读取文件**：使用开源 **`apfs-fuse`**（`sudo apfs-fuse -o allow_other /dev/sdX1 /media/mac_apfs`）。
* **分区调整禁忌**：GParted **完全无法调整 APFS Container 大小**，APFS 分区缩放必须回到 macOS `diskutil` 操作。

---

## 九、 Kali 无线渗透外置 USB 网卡选型全解 (M3 Pro + VMware ARM64)

### 1. 必备两大硬件特征
1. 支持 **Monitor Mode (监听模式)**。
2. 支持 **Packet Injection (数据包注入)** 且在 Linux ARM64 内核下有内建/成熟驱动。

### 2. 推荐芯片与型号对比
| 芯片型号 | 支持频段/协议 | Kali 驱动状态 | 推荐型号/价格 | 选型建议 |
| :--- | :--- | :--- | :--- | :--- |
| **MediaTek MT7612U** | 2.4G + 5GHz (WiFi 5) | **Linux 内核原生免驱** | EDUP EP-AC1689 (~￥75) | **80% 人的首选！** 性价比无敌，即插即用，稳定性极佳。 |
| **MediaTek MT7921AUM**| 2.4G + 5G + **6GHz (WiFi 6E)** + BLE 5.2 | **Linux 5.19+ 原生免驱** | ALFA AWUS036AXML (~￥600)<br>EDUP EP-AX1696 联发科版 (~￥170) | **WiFi 6E 顶配旗舰**。战未来，支持 6G 抓包与蓝牙渗透。 |
| **Realtek RTL8812AU** | 2.4G + 5GHz (WiFi 5) | `realtek-rtl8812au-dkms` 一键安装 | ALFA AWUS036ACH / 拓实 N95 (~￥90) | 经典安全标杆，功耗大、信号极强。 |

### 3. ⛔ 极力避坑黑名单（千万不要买！）
* **Realtek RTL8832AU / RTL8832CU / RTL8852AU (WiFi 6)**：如 `EDUP EP-AX1696GS`、`EP-AX1697S`。Linux 开源社区 `morrownr/USB-WiFi` 明确列为黑名单！无原生驱动，ARM64 编译频频报错，监听模式极易崩溃掉包。
* **Intel 全系无线网卡**：在 Linux 下均**不支持 Packet Injection 数据包注入**。

---

## 十、 macOS 环境下 `smartmontools` 路径修复与软件彻底清理

### 1. DiskMoni 等 GUI 软件不识别 `smartctl` 的修复
* **原因**：Apple Silicon Mac 上 Homebrew 安装路径为 `/opt/homebrew/bin/smartctl`，而第三方软件默认在 `/usr/local/bin` 中查找。
* **全局软链接修复**：
  ```bash
  sudo mkdir -p /usr/local/bin && sudo ln -sf /opt/homebrew/bin/smartctl /usr/local/bin/smartctl
  ```

### 2. 彻底干净卸载 DiskMoni (含后台 Helper 及配置文件)
```bash
# 1. 结束进程
pkill -9 -i diskmoni

# 2. 清理配置与缓存
rm -rf ~/Library/Preferences/com.agilebox.DiskMoni.plist
rm -rf ~/Library/Caches/com.agilebox.DiskMoni
rm -rf ~/Library/Application\ Support/*diskmoni*

# 3. 删除主程序与后台 Helper
sudo rm -rf /Applications/DiskMoni.app
sudo rm -rf /Library/LaunchDaemons/*diskmoni*
sudo rm -rf /Library/PrivilegedHelperTools/*diskmoni*
```


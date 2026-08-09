import SwiftUI

struct AboutView: View {
    @ObservedObject var langManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 12) {
            // Header: App Logo & Title
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .cornerRadius(14)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("DIT Renamer")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Release 1.1")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    }
                    Text(langManager.text("专业影视 DIT 卡卷重命名与自动化管理工具", "Professional Cinema DIT Volume Renamer & Media Utility"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
            
            Divider()
            
            // Primary Purpose Section
            VStack(alignment: .leading, spacing: 6) {
                Text(langManager.text("核心宗旨与数据安全追求", "Core Purpose & Data Safety Commitment"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text(langManager.text(
                    "本软件致力于解决 Sony FX3、DJI Ronin 4D 等数字摄影机在配置机位号后卡卷名仍为通用默认名称的行业痛点，通过秒级规范卷号并刷新系统句柄，解决 Silverstack 并发拷贝冲突；同时内置专业级 ParaShoot 擦除历史追踪与中/英双语审计报告导出功能，为影视剧组数据管理提供全流程安全归档保障。",
                    "Designed for professional DIT workflows, this utility eliminates volume label conflicts on cameras like Sony FX3 and DJI Ronin 4D to ensure seamless Silverstack concurrent offloads. It integrates complete ParaShoot erasure history tracking and bilingual PDF audit report exports, providing uncompromising data safety and professional archive handovers."
                ))
                .font(.caption)
                .foregroundColor(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(Color.blue.opacity(0.06))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.2), lineWidth: 1))
            
            // Key Features (6 Features)
            VStack(alignment: .leading, spacing: 6) {
                Text(langManager.text("核心特点", "Key Features"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 5) {
                    featureRow(
                        title: langManager.text("系统层深度重挂载", "System-level Deep Remount"),
                        desc: langManager.text("自动广播 Mount/Unmount 事件以刷新系统文件句柄，保障 Silverstack 等软件并发拷贝。", "Flushes file handles via system mount events to ensure error-free concurrent offloads in Silverstack.")
                    )
                    featureRow(
                        title: langManager.text("ParaShoot 审计历史与 PDF 导出", "ParaShoot Audit Trail & PDF Export"),
                        desc: langManager.text("完整整合 ParaShoot 历史擦除日志，支持按拍摄日期自动分组折叠与一键导出专业中/英 PDF 审查报告。", "Integrates ParaShoot erasure logs with date-based grouping and one-click bilingual PDF audit report exports.")
                    )
                    featureRow(
                        title: langManager.text("智能识别卡卷内容", "Smart Volume Content Identification"),
                        desc: langManager.text("精准校验卡内媒体属性，针对未设机位号、跨日未格式化旧卡、纯空卡与静态照片卡自动提供安全保护，确保盘号规范可靠。", "Accurately validates media attributes to safeguard unconfigured camera IDs, unformatted residual cards, empty volumes, and photo-only cards.")
                    )
                    featureRow(
                        title: langManager.text("电影级多机型精准解析", "Cinema Camera Parsing Engine"),
                        desc: langManager.text("全面适配 Sony FX 全系 (FX3/FX6/FX9/VENICE)、ARRI、RED (.RDC/.RDM)、Nikon Cinema (ZR/Z9，支持 R3D/N-RAW) 与 DJI 4D。", "Full support for Sony FX series, ARRI, RED (.RDC/.RDM), Nikon Cinema (ZR/Z9 with R3D/N-RAW), and DJI 4D.")
                    )
                    featureRow(
                        title: langManager.text("结构推演与文件系统过滤", "Structure Inference & Filtering"),
                        desc: langManager.text("深入分析卡内目录推演卷号，同时支持智能过滤 UDF/X2XFUSE 等电影卡与 APFS/NTFS 数据盘。", "Scans directory hierarchy to infer Camera ID & Roll while intelligently filtering UDF/X2XFUSE and APFS/NTFS volumes.")
                    )
                    featureRow(
                        title: langManager.text("Codex HDE 容量计算引擎", "Codex HDE Capacity Calculator"),
                        desc: langManager.text("智能检测系统 Codex HDE CLI 命令行工具，结合无损编码算法模型，实时精准推演电影素材 HDE 压缩后体积与存储节省空间。", "Detects Codex HDE CLI tools & applies lossless algorithm models to compute real-time ARRIRAW post-compression storage savings.")
                    )
                    featureRow(
                        title: langManager.text("100% Pure Swift 纯原生架构", "100% Pure Swift Native Architecture"),
                        desc: langManager.text("基于 macOS 原生 Cocoa 框架打造，内存占用约 100MB，待机 CPU 占用率 0.0%，严格遵循 Apple HIG 原生设计规范。", "Built on native macOS Cocoa framework with ~100MB memory footprint, 0.0% idle CPU usage, and strict Apple HIG compliance.")
                    )
                }
            }
            .padding(.horizontal, 4)
            
            Divider()
            
            // Social Media & REDNOTE Contact Card
            HStack(spacing: 12) {
                Image(systemName: "number.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(langManager.text("官方小红书", "Official REDNOTE"))
                        .font(.caption)
                        .fontWeight(.bold)
                    Text(langManager.text("小红书：DIT247", "REDNOTE: DIT247"))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                Spacer()
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            
            Divider()
            
            // Footer: Language Switcher & Close
            HStack {
                Picker("", selection: $langManager.currentLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                
                Spacer()
                
                Button(langManager.text("关闭", "Close")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 520)
        .preferredColorScheme(.dark)
    }
    
    private func featureRow(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("• \(title)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(desc)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 10)
        }
    }
}

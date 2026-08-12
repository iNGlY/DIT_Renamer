// Copyright 2026 DIT247
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct AboutView: View {
    @ObservedObject var langManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    Divider()
                    purposeSection
                    featuresSection
                    versionBoundarySection
                    contactSection
                }
                .padding(18)
            }

            Divider()
            footer
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
        .frame(width: 600, height: 680)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
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
                    Text("Release \(DITRenamerAppInfo.shortVersion)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                }
                Text(langManager.text(
                    "拷贝前确认摄影机卡卷名，并记录每次重命名",
                    "Confirm camera-card volume names before offload and record every rename"
                ))
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var purposeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading(
                icon: "shield.checkered",
                title: langManager.text("DIT Renamer 的用途", "What DIT Renamer Does")
            )

            Text(langManager.text(
                "DIT Renamer 面向影视现场拍摄数据管理，用于在素材拷贝开始前识别已挂载的可移除摄影机存储卡，并根据卡内目录和素材命名证据提供卷名建议。\n\n执行重命名前，软件会复核挂载路径、BSD 分区节点和卷 UUID；重命名后自动强制卸载并重新挂载同一设备，帮助刷新 macOS 和 Silverstack 对同名存储卡的识别状态。\n\nDIT Renamer 不执行素材拷贝、checksum 校验或卡片擦除，也不替代 Silverstack 等专业数据管理软件。",
                "DIT Renamer is designed for on-set media management. Before an offload begins, it identifies mounted removable camera media and provides volume-name suggestions based on observable folder structures and clip-name evidence.\n\nBefore renaming, the app verifies the mount path, BSD partition node, and volume UUID. After renaming, it force-unmounts and remounts the same device to refresh how macOS and applications such as Silverstack identify cards that previously shared the same volume name.\n\nDIT Renamer does not copy media, calculate transfer checksums, or erase cards, and does not replace professional data-management applications such as Silverstack."
            ))
            .font(.caption)
            .foregroundColor(.primary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.2), lineWidth: 1))
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading(
                icon: "checklist",
                title: langManager.text("功能", "Features")
            )

            featureRow(
                title: langManager.text("安全重命名与强制重挂载", "Safe Rename and Forced Remount"),
                desc: langManager.text(
                    "重命名前后复核 BSD 节点、卷 UUID、Media UUID 和挂载状态；重命名成功后强制卸载并重新挂载同一分区。",
                    "Verifies the BSD node, volume UUID, available media UUID, and mount state before and after renaming, then force-remounts the same partition."
                )
            )
            featureRow(
                title: langManager.text("摄影机媒体结构分析", "Camera Media Structure Analysis"),
                desc: langManager.text(
                    "只读扫描卡内目录和首末素材，根据可观察证据提供机位号和卷号建议；证据不足时要求人工确认，不把文件名模式当作确定的摄像机型号。",
                    "Read-only scanning examines card folders and first/last clips to suggest camera and roll identifiers. Uncertain results require manual confirmation."
                )
            )
            featureRow(
                title: langManager.text("Sony 型号元数据识别", "Sony Model Metadata Detection"),
                desc: langManager.text(
                    "优先读取 Sony 卡内 XML/XMP 元数据；没有明确型号时，可选择使用 exiftool 检查一条代表性素材。exiftool 可在设置中禁用。",
                    "Reads Sony XML/XMP metadata first. When no explicit model is available, optional exiftool detection can inspect one representative clip and may be disabled in Settings."
                )
            )
            featureRow(
                title: langManager.text("自动重命名安全条件", "Automatic Rename Safety Conditions"),
                desc: langManager.text(
                    "只有扫描完整、命名证据置信度足够且当前卷名属于通用名称时才允许自动处理。空卡、照片卡、未配置机位、残留旧素材和未识别媒体不会自动重命名。",
                    "Automatic renaming is limited to complete, high-confidence scans of generically named volumes. Empty, photo-only, unconfigured, residual, and unrecognized media require manual review."
                )
            )
            featureRow(
                title: langManager.text("卷名与设备过滤保护", "Volume Name and Device Filtering"),
                desc: langManager.text(
                    "限制卷名字符，并对 FAT、MS-DOS 和 exFAT 执行 11 字符上限。Apple Disk Image Media、网络卷和系统虚拟卷始终排除；其他文件系统可按设置过滤。",
                    "Enforces supported volume-label characters and the 11-character FAT, MS-DOS, and exFAT limit. Disk images, network volumes, and system virtual volumes are always excluded."
                )
            )
            featureRow(
                title: langManager.text("重命名与 ParaShoot 审计", "Rename and ParaShoot Audit"),
                desc: langManager.text(
                    "保存原始卷名、新卷名、UUID、BSD 节点、首末素材和操作时间；以只读方式解析 ParaShoot 日志，并按软件当前语言导出中文或英文 PDF。高置信度日志关联结果由用户选择是否输出。",
                    "Records original and new names, UUIDs, BSD nodes, first/last clips, and timestamps. ParaShoot logs are read-only and PDF reports follow the active application language, with optional high-confidence association details."
                )
            )
            featureRow(
                title: langManager.text("ARRIRAW / HDE 容量参考估算", "ARRIRAW / HDE Reference Estimate"),
                desc: langManager.text(
                    "对检测到的 ARRIRAW 内容提供基于固定模型的 HDE 容量参考估算，不调用外部处理工具，也不代表最终编码结果。",
                    "Provides a model-based HDE storage estimate for detected ARRIRAW media without invoking an external processing tool or guaranteeing final encoded size."
                )
            )
            featureRow(
                title: langManager.text("原生 Swift 应用", "Native Swift Application"),
                desc: langManager.text(
                    "应用使用 Swift、SwiftUI 和 AppKit 构建。卷管理通过 macOS diskutil 完成，exiftool 为可选工具。",
                    "Built with Swift, SwiftUI, and AppKit. Volume operations use macOS diskutil, and exiftool is optional."
                )
            )
        }
    }

    private var versionBoundarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeading(
                icon: "puzzlepiece.extension",
                title: langManager.text("版本边界", "Version Boundary")
            )
            Text(langManager.text(
                "DIT Printer 是独立扩展，不包含在 DIT Renamer 应用中。Renamer 仅提供只读审计数据接口，不能通过 Printer 触发重命名、校验或擦除操作。",
                "DIT Printer is a separate extension and is not included in the DIT Renamer application. Renamer only exposes a read-only audit-data interface; Printer cannot trigger rename, verification, or erase operations."
            ))
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Text(langManager.text(
                "原始发布者：DIT247 · Apache License 2.0 · github.com/iNGlY/DIT_Renamer",
                "Original publisher: DIT247 · Apache License 2.0 · github.com/iNGlY/DIT_Renamer"
            ))
            .font(.caption2)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .cornerRadius(8)
    }

    private var contactSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "number.circle.fill")
                .font(.title2)
                .foregroundColor(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(langManager.text("联系 DIT247", "Contact DIT247"))
                    .font(.caption)
                    .fontWeight(.bold)
                Text(langManager.text("小红书：DIT247", "Xiaohongshu: DIT247"))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            Spacer()
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }

    private var footer: some View {
        HStack {
            Picker("", selection: $langManager.currentLanguage) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Spacer()

            UpdateActionButton()
                .buttonStyle(.bordered)

            Button(langManager.text("关闭", "Close")) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func sectionHeading(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.blue)
        }
    }

    private func featureRow(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(desc)
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .cornerRadius(6)
    }
}

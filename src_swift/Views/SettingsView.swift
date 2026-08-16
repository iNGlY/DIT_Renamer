import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var langManager = LanguageManager.shared
    @ObservedObject var monitor: VolumeMonitor

    // 非摄影机格式排除 (默认开启)
    @AppStorage("excludeAPFS")     private var excludeAPFS:    Bool = true
    @AppStorage("excludeNTFS")     private var excludeNTFS:    Bool = true
    // 规则化命名摄影机排除
    @AppStorage("excludeUDF")      private var excludeUDF:     Bool = true  // ARRI Alexa/Amira, Sony Venice
    @AppStorage("excludeHDECodex") private var excludeCodex:   Bool = true  // Codex HDE X2X FUSE
    @AppStorage("enableExifToolModelDetection") private var enableExifToolModelDetection: Bool = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("showMainWindowForReview") private var showMainWindowForReview: Bool = false
    @AppStorage("startInBackground") private var startInBackground: Bool = true
    
    // 卷名黑名单
    @AppStorage("customIgnores") private var customIgnoresData: Data = Data()
    @State private var newIgnoreInput: String = ""
    
    var customIgnores: [String] {
        (try? JSONDecoder().decode([String].self, from: customIgnoresData)) ?? ["TIME MACHINE", "MACINTOSH HD"]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with Close Button
            HStack {
                Text(langManager.text("偏好设置", "Settings"))
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                // MARK: - Background operation and attention
                sectionCard {
                    sectionHeader(
                        icon: "menubar.rectangle",
                        title: langManager.text("后台运行与提醒", "Background Operation & Alerts"),
                        subtitle: langManager.text(
                            "DIT Renamer 默认驻留菜单栏。主窗口关闭后仍会继续检测存储卡和维护审批队列。",
                            "DIT Renamer normally lives in the menu bar. Closing the main window does not stop card monitoring or the review queue."
                        )
                    )

                    VStack(spacing: 0) {
                        toggleRow(
                            label: langManager.text("启动时隐藏主窗口", "Hide main window at launch"),
                            detail: langManager.text("启动后只显示菜单栏图标，需要时再打开主窗口。", "Launch with only the menu bar item visible and open the main window on demand."),
                            binding: $startInBackground,
                            onChange: {}
                        )
                        Divider().padding(.horizontal, 12)
                        toggleRow(
                            label: langManager.text("需要人工确认时发送通知", "Notify when manual review is required"),
                            detail: langManager.text("通知只负责提醒，不能直接执行重命名。", "Notifications only draw attention and can never execute a rename."),
                            binding: $notificationsEnabled,
                            onChange: { OperatorAttentionCenter.shared.refreshAuthorizationStatus() }
                        )
                        Divider().padding(.horizontal, 12)
                        toggleRow(
                            label: langManager.text("需要确认时自动显示主窗口", "Show main window when review is required"),
                            detail: langManager.text("关闭时保持后台运行，仅依靠菜单栏数量和系统通知。", "When disabled, the app stays in the background and relies on the menu-bar count and notifications."),
                            binding: $showMainWindowForReview,
                            onChange: {}
                        )
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // MARK: - 1. 规则化命名摄影机排除
                sectionCard {
                    sectionHeader(icon: "video.badge.checkmark", title: langManager.text("规则化命名摄影机排除", "Exclude Pre-Named Camera Volumes"),
                                  subtitle: langManager.text("勾选后，已有规范卷名的摄影机卡会从侧边栏隐藏。", "When enabled, camera cards with an established volume name are hidden from the sidebar."))
                    
                    VStack(spacing: 0) {
                        toggleRow(
                            label: langManager.text("ARRI / Sony VENICE / RED (UDF)", "ARRI / Sony VENICE / RED (UDF)"),
                            detail: langManager.text("这类摄影机通常使用 UDF，卷名由摄影机在格式化时生成。", "These cameras commonly use UDF and set the volume name when the card is formatted."),
                            binding: $excludeUDF,
                            onChange: { monitor.refreshVolumes() }
                        )
                        Divider().padding(.horizontal, 12)
                        toggleRow(
                            label: langManager.text("ARRI / Codex HDE (X2XFUSE / HFS+)", "ARRI / Codex HDE (X2XFUSE / HFS+)"),
                            detail: langManager.text("Codex Capture 或 Compact Drive 在 Mac 上通常挂载为 X2XFUSE。", "Codex Capture and Compact Drive media commonly mount as X2XFUSE on Mac."),
                            binding: $excludeCodex,
                            onChange: { monitor.refreshVolumes() }
                        )
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // MARK: - 2. 非摄影机格式排除
                sectionCard {
                    sectionHeader(icon: "nosign", title: langManager.text("非摄影机格式排除", "Exclude Non-Camera Filesystems"),
                                  subtitle: langManager.text("排除通常不用于摄影机卡的文件系统。SMBFS、AUTOFS、DEVFS 和 Apple Disk Image Media 始终排除。", "Hide filesystems that are not normally used for camera cards. SMBFS, AUTOFS, DEVFS, and Apple Disk Image Media are always excluded."))
                    
                    VStack(spacing: 0) {
                        toggleRow(
                            label: "APFS",
                            detail: langManager.text("macOS 系统盘、Time Machine 备份盘", "macOS system volumes, Time Machine backups"),
                            binding: $excludeAPFS,
                            onChange: { monitor.refreshVolumes() }
                        )
                        Divider().padding(.horizontal, 12)
                        toggleRow(
                            label: "NTFS",
                            detail: langManager.text("Windows 数据盘、移动硬盘", "Windows data drives, external HDDs"),
                            binding: $excludeNTFS,
                            onChange: { monitor.refreshVolumes() }
                        )
                        Divider().padding(.horizontal, 12)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SMBFS / AUTOFS / DEVFS")
                                    .font(.body)
                                Text(langManager.text("网络共享盘 / 系统虚拟盘（强制排除）", "Network shares / system virtual volumes (always excluded)"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        Divider().padding(.horizontal, 12)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Disk Image Media")
                                    .font(.body)
                                Text(langManager.text("DMG、稀疏镜像及其他磁盘镜像挂载卷（强制排除）", "Mounted DMG, sparse image, and other disk image volumes (always excluded)"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // MARK: - 3. Camera model detection
                sectionCard {
                    sectionHeader(
                        icon: "camera.metering.unknown",
                        title: langManager.text("摄像机型号元数据识别", "Camera Model Metadata Detection"),
                        subtitle: langManager.text("优先读取摄影机原生 Sidecar；仅在其中没有明确型号时，才对一条代表性素材使用 exiftool 回退识别。只显示元数据明确给出的机型，不从文件名推断。", "Checks camera-native sidecars first. Only when they have no explicit model does exiftool inspect one representative media file. It shows only an explicit model from metadata, never an inference from filenames.")
                    )

                    toggleRow(
                        label: langManager.text("启用 exiftool 型号识别", "Enable exiftool model detection"),
                        detail: langManager.text("关闭后不启动 exiftool；Sidecar/XML 的只读识别和现有卷名规则不受影响。", "When disabled, exiftool is never launched; read-only sidecar/XML recognition and existing volume-name rules are unchanged."),
                        binding: $enableExifToolModelDetection,
                        onChange: { monitor.refreshVolumes() }
                    )

                    HStack(spacing: 6) {
                        Image(systemName: MediaScanner.exifToolPath == nil ? "exclamationmark.triangle" : "checkmark.circle")
                            .foregroundColor(MediaScanner.exifToolPath == nil ? .orange : .green)
                        Text(MediaScanner.exifToolPath == nil
                             ? langManager.text("未安装 exiftool。只有 Sidecar/XML 无法识别型号时才需要它；请手动执行 brew install exiftool，或从 exiftool.org 安装。", "exiftool is not installed. It is only needed when sidecar/XML metadata cannot identify the model. Install it manually with brew install exiftool or from exiftool.org.")
                             : langManager.text("exiftool 已安装。", "exiftool is available."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, MediaScanner.exifToolPath == nil ? 4 : 10)

                    if MediaScanner.exifToolPath == nil {
                        Link(langManager.text("打开 exiftool 官方安装页", "Open the exiftool installation page"), destination: URL(string: "https://exiftool.org/")!)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 10)
                    }
                }

                // MARK: - 4. Volume name blocklist
                sectionCard {
                    sectionHeader(icon: "list.bullet.rectangle", title: langManager.text("卷名黑名单", "Volume Name Blocklist"),
                                  subtitle: langManager.text("以下卷名将被自动忽略，不显示在侧边栏中。", "Volumes with these names will be automatically ignored in the sidebar."))
                    
                    HStack {
                        TextField(langManager.text("输入要排除的卷名 (例如: BackupDisk)", "Volume name to block (e.g. BackupDisk)"), text: $newIgnoreInput)
                            .textFieldStyle(.roundedBorder)
                        Button(action: addIgnoreRule) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newIgnoreInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    
                    VStack(spacing: 6) {
                        ForEach(Array(customIgnores.enumerated()), id: \.offset) { idx, name in
                            HStack {
                                Text(name)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button(langManager.text("移除", "Remove")) {
                                    removeIgnoreRule(at: idx)
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.red)
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                }
                
                Spacer()
            }
            }
            .padding(.bottom, 24)
        }
        .frame(minWidth: 440, idealWidth: 520, maxWidth: 620, minHeight: 460, idealHeight: 600, maxHeight: 760)
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
    
    @ViewBuilder
    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(.blue)
            Text(title).font(.headline)
        }
        Text(subtitle).font(.caption).foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private func toggleRow(label: String, detail: String, binding: Binding<Bool>, onChange: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.body)
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: binding.wrappedValue) { _, _ in onChange() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    private func addIgnoreRule() {
        let trimmed = newIgnoreInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty, !customIgnores.contains(trimmed) else { return }
        var list = customIgnores
        list.append(trimmed)
        saveCustomIgnores(list)
        monitor.refreshVolumes()
        newIgnoreInput = ""
    }
    
    private func removeIgnoreRule(at index: Int) {
        var list = customIgnores
        list.remove(at: index)
        saveCustomIgnores(list)
        monitor.refreshVolumes()
    }
    
    private func saveCustomIgnores(_ list: [String]) {
        if let encoded = try? JSONEncoder().encode(list) {
            customIgnoresData = encoded
        }
    }
}

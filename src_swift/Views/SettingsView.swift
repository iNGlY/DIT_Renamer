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
                
                // MARK: - 1. 规则化命名摄影机排除
                sectionCard {
                    sectionHeader(icon: "video.badge.checkmark", title: langManager.text("规则化命名摄影机排除", "Exclude Pre-Named Camera Volumes"),
                                  subtitle: langManager.text("勾选后，已具有规则化卷名的专业摄影机存储卡将被屏蔽，不显示在侧边栏。", "When enabled, camera volumes with standardized naming conventions will be hidden from the sidebar."))
                    
                    VStack(spacing: 0) {
                        toggleRow(
                            label: langManager.text("ARRI / Sony VENICE / RED (UDF)", "ARRI / Sony VENICE / RED (UDF)"),
                            detail: langManager.text("高端电影机常采用 UDF 格式，卷名在格式化时已按机位和卷号严格规则化生成", "High-end cinema cameras use UDF filesystem with standardized naming conventions"),
                            binding: $excludeUDF,
                            onChange: { monitor.refreshVolumes() }
                        )
                        Divider().padding(.horizontal, 12)
                        toggleRow(
                            label: langManager.text("ARRI / Codex HDE (X2XFUSE / HFS+)", "ARRI / Codex HDE (X2XFUSE / HFS+)"),
                            detail: langManager.text("Codex Capture/Compact Drive 存储卡。Mac 上挂载为 X2XFUSE，卷名通常已规范化", "Codex Capture/Compact Drive mounts as X2XFUSE on Mac with standardized volume names"),
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
                                  subtitle: langManager.text("排除与摄影机存储无关的文件系统格式。SMBFS / AUTOFS / DEVFS 为强制排除项，不可关闭。", "Exclude filesystems unrelated to camera storage. SMBFS / AUTOFS / DEVFS are always excluded."))
                    
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
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // MARK: - 3. 卷名黑名单
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
        .frame(width: 520, height: 600)
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
                .onChange(of: binding.wrappedValue) { _ in onChange() }
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
        newIgnoreInput = ""
    }
    
    private func removeIgnoreRule(at index: Int) {
        var list = customIgnores
        list.remove(at: index)
        saveCustomIgnores(list)
    }
    
    private func saveCustomIgnores(_ list: [String]) {
        if let encoded = try? JSONEncoder().encode(list) {
            customIgnoresData = encoded
        }
    }
}

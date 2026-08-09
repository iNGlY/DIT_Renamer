import SwiftUI

struct SidebarView: View {
    @ObservedObject var monitor: VolumeMonitor
    @Binding var selectedVolume: MountedVolume?
    @Binding var isAutoRenameEnabled: Bool
    
    @ObservedObject var langManager = LanguageManager.shared
    @State private var sidebarTab: Int = 0
    @State private var knownVolumeIDs: Set<String> = []
    @AppStorage("ignoredVolumePaths") private var ignoredPathsData: Data = Data()
    
    var ignoredPaths: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: ignoredPathsData)) ?? []
        }
        set {
            ignoredPathsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
    
    var activeVolumes: [MountedVolume] {
        monitor.volumes.filter { !ignoredPaths.contains($0.path) }
    }
    
    var ignoredVolumes: [MountedVolume] {
        monitor.volumes.filter { ignoredPaths.contains($0.path) }
    }

    var recommendedVolumes: [MountedVolume] {
        activeVolumes.filter { !$0.isUniqueCameraName }
    }
    
    var otherVolumes: [MountedVolume] {
        activeVolumes.filter { $0.isUniqueCameraName }
    }

    var body: some View {
        VStack(spacing: 12) {
            // App Title Header
            HStack {
                Image(systemName: "externaldrive.fill.badge.checkmark")
                    .foregroundColor(.blue)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 1) {
                    Text("DIT Renamer")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Release 1.1")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            // Auto-Rename Switch
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(langManager.text("符合条件自动改名", "Auto-Rename Queue"))
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(langManager.text("符合卷名检测自动重命名", "Auto rename compliant volumes"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $isAutoRenameEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .padding(.horizontal, 10)
            
            // Segmented Tab Picker
            Picker("", selection: $sidebarTab) {
                Text("\(langManager.text("活动卷", "Active")) (\(activeVolumes.count))").tag(0)
                Text("\(langManager.text("已忽略", "Ignored")) (\(ignoredVolumes.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)

            // Device List
            List {
                if sidebarTab == 0 {
                    if recommendedVolumes.isEmpty && otherVolumes.isEmpty {
                        Text(langManager.text("未检测到有效卡片", "No Volumes Detected"))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        if !recommendedVolumes.isEmpty {
                            Section(header: Text(langManager.text("推荐重命名", "RECOMMENDED FOR RENAMING")).font(.caption2)) {
                                ForEach(recommendedVolumes) { vol in
                                    volumeRow(vol: vol, isIgnored: false)
                                }
                            }
                        }
                        if !otherVolumes.isEmpty {
                            Section(header: Text(langManager.text("其他卡卷", "OTHER VOLUMES")).font(.caption2)) {
                                ForEach(otherVolumes) { vol in
                                    volumeRow(vol: vol, isIgnored: false)
                                }
                            }
                        }
                    }
                } else {
                    Section(header: Text(langManager.text("已忽略设备列表", "IGNORED VOLUMES")).font(.caption2)) {
                        if ignoredVolumes.isEmpty {
                            Text(langManager.text("暂无被忽略设备", "No Ignored Volumes"))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        } else {
                            ForEach(ignoredVolumes) { vol in
                                volumeRow(vol: vol, isIgnored: true)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Bottom Footer (Language Switcher, Settings & About)
            HStack {
                Button(action: {
                    langManager.currentLanguage = (langManager.currentLanguage == .zh ? .en : .zh)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text(langManager.currentLanguage == .zh ? "EN" : "中文")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(langManager.text("切换语言 (Switch Language)", "Switch Language"))
                
                Spacer()
                
                Button(action: { onShowSettings() }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(langManager.text("偏好设置", "Settings"))
                
                Button(action: { onShowAbout() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text(langManager.text("关于软件", "About"))
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(langManager.text("关于 DIT Renamer", "About DIT Renamer"))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
        .onAppear {
            knownVolumeIDs = Set(activeVolumes.map(\.id))
            if selectedVolume == nil, let first = activeVolumes.first {
                selectedVolume = first
            }
        }
        .onChange(of: monitor.volumes) { _, newVolumes in
            let active = newVolumes.filter { !ignoredPaths.contains($0.path) }
            let newIDs = Set(active.map(\.id))
            let inserted = active.first { !knownVolumeIDs.contains($0.id) }
            knownVolumeIDs = newIDs

            if let selectedVolume, !newIDs.contains(selectedVolume.id) {
                self.selectedVolume = inserted ?? active.first
            } else if self.selectedVolume == nil {
                self.selectedVolume = inserted ?? active.first
            } else if let inserted {
                // A newly mounted card is the only event that may change selection.
                self.selectedVolume = inserted
            }
        }
    }
    
    var onShowAbout: () -> Void = {}
    var onShowSettings: () -> Void = {}
    
    private func volumeRow(vol: MountedVolume, isIgnored: Bool) -> some View {
        let isRenamed = !vol.isGenericName && RenameHistoryStore.shared.isRenamed(volumeName: vol.name)
        
        let iconName: String
        let iconColor: Color
        if isRenamed {
            iconName = "checkmark.seal.fill"
            iconColor = .green
        } else if vol.isGenericName {
            iconName = "film.fill"
            iconColor = .blue
        } else {
            iconName = "sdcard.fill"
            iconColor = .secondary
        }
        
        return HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(vol.name)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if isRenamed {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8))
                            Text(langManager.text("已重命名", "Renamed"))
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                    } else if vol.isGenericName {
                        Text("RAW")
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                
                // Original Name & BSD Device Tree Path
                Text("\(langManager.text("原始", "Orig")): \(vol.originalName) · /dev/\(vol.bsdNode)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Ignore / Restore Button
            Button(action: {
                toggleIgnore(vol: vol, isIgnored: isIgnored)
            }) {
                Image(systemName: isIgnored ? "arrow.uturn.backward.circle" : "eye.slash")
                    .foregroundColor(isIgnored ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help(isIgnored ? langManager.text("恢复设备", "Restore Volume") : langManager.text("一键忽略此设备", "Ignore Volume"))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isIgnored {
                selectedVolume = vol
            }
        }
    }
    
    private func toggleIgnore(vol: MountedVolume, isIgnored: Bool) {
        var set = (try? JSONDecoder().decode(Set<String>.self, from: ignoredPathsData)) ?? []
        if isIgnored {
            set.remove(vol.path)
        } else {
            set.insert(vol.path)
            if selectedVolume?.id == vol.id {
                selectedVolume = nil
            }
        }
        if let encoded = try? JSONEncoder().encode(set) {
            ignoredPathsData = encoded
        }
    }
}

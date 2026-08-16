import SwiftUI

struct SidebarView: View {
    @ObservedObject var monitor: VolumeMonitor
    @Binding var selectedVolume: MountedVolume?
    @Binding var isAutoRenameEnabled: Bool
    
    @ObservedObject var langManager = LanguageManager.shared
    @State private var sidebarTab: Int = 0
    @State private var knownVolumeIDs: Set<String> = []
    @ObservedObject private var ignoredStore = IgnoredVolumeStore.shared
    
    var activeVolumes: [MountedVolume] {
        monitor.volumes.filter { !ignoredStore.paths.contains($0.path) }
    }
    
    var ignoredVolumes: [MountedVolume] {
        monitor.volumes.filter { ignoredStore.paths.contains($0.path) }
    }

    var recommendedVolumes: [MountedVolume] {
        activeVolumes.filter { $0.canAttemptManualRename && !$0.isUniqueCameraName }
    }
    
    var otherVolumes: [MountedVolume] {
        activeVolumes.filter { !$0.canAttemptManualRename || $0.isUniqueCameraName }
    }

    var body: some View {
        VStack(spacing: 12) {
            // App Title Header
            HStack {
                Image(systemName: "sdcard.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 1) {
                    Text("DIT Renamer")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Release \(DITRenamerAppInfo.shortVersion)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help(langManager.text("重新读取存储卡并扫描素材", "Refresh cards and rescan media"))
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            // Auto-Rename Switch
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(langManager.text("符合条件自动改名", "Auto-Rename Queue"))
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(langManager.text("符合条件的卷会自动进入队列", "Queue volumes that meet the rename rules"))
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
                            Text(langManager.text("未检测到可处理的卷", "No eligible volumes detected"))
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

            // Bottom Footer (Update, Language, Settings & About)
            HStack(spacing: 2) {
                UpdateActionButton(compact: true)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)

                Button(action: {
                    langManager.currentLanguage = (langManager.currentLanguage == .zh ? .en : .zh)
                }) {
                    footerActionLabel(
                        icon: "globe",
                        title: langManager.currentLanguage == .zh ? "EN" : "中文"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .help(langManager.text("切换语言 (Switch Language)", "Switch Language"))

                Button(action: { onShowSettings() }) {
                    footerActionLabel(
                        icon: "gearshape",
                        title: langManager.text("设置", "Settings")
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .help(langManager.text("偏好设置", "Settings"))

                Button(action: { onShowAbout() }) {
                    footerActionLabel(
                        icon: "info.circle",
                        title: langManager.text("关于", "About")
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .help(langManager.text("关于 DIT Renamer", "About DIT Renamer"))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .onAppear {
            knownVolumeIDs = Set(activeVolumes.map(\.id))
            if selectedVolume == nil, let first = activeVolumes.first {
                selectedVolume = first
            }
        }
        .onChange(of: monitor.volumes) { _, newVolumes in
            let active = newVolumes.filter { !ignoredStore.paths.contains($0.path) }
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
    
    var onRefresh: () -> Void = {}
    var onShowAbout: () -> Void = {}
    var onShowSettings: () -> Void = {}

    private func footerActionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
        }
        .font(.caption2)
        .fontWeight(.medium)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, minHeight: 22)
        .contentShape(Rectangle())
    }
    
    private func volumeRow(vol: MountedVolume, isIgnored: Bool) -> some View {
        let isRenamed = !vol.isGenericName && RenameHistoryStore.shared.isRenamed(volumeName: vol.name)
        
        let iconName: String
        let iconColor: Color
        if isRenamed {
            iconName = "checkmark.seal.fill"
            iconColor = .green
        } else if vol.isGenericName {
            iconName = "sdcard"
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

                    if vol.isReadOnly {
                        Text(langManager.text("只读", "Read Only"))
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    } else if !vol.canAutomaticallyRename {
                        Text(langManager.text("手动", "Manual"))
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.yellow.opacity(0.2))
                            .foregroundColor(.yellow)
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
        ignoredStore.setIgnored(!isIgnored, volume: vol)
        if !isIgnored, selectedVolume?.id == vol.id {
            selectedVolume = nil
        }
    }
}

import SwiftUI

struct ResponsiveWorkspaceView: View {
    @ObservedObject var monitor: VolumeMonitor
    @ObservedObject var ignoredVolumes: IgnoredVolumeStore
    @Binding var selectedVolume: MountedVolume?
    @Binding var isAutoRenameEnabled: Bool
    @Binding var selectedAuditTab: AuditTab

    let onShowSettings: () -> Void
    let onShowAbout: () -> Void

    @ObservedObject private var langManager = LanguageManager.shared
    @State private var showVolumes = false
    @State private var showAudit = false

    var body: some View {
        GeometryReader { proxy in
            let mode = WorkspaceLayoutMode.resolve(width: proxy.size.width)

            VStack(spacing: 0) {
                if mode != .expanded {
                    compactToolbar(mode: mode)
                    Divider()
                }

                HStack(spacing: 0) {
                    if mode != .compact {
                        sidebar
                            .frame(width: mode == .expanded ? 260 : 240)
                        Divider()
                    }

                    MainDetailView(
                        volume: $selectedVolume,
                        monitor: monitor,
                        isAutoRenameEnabled: $isAutoRenameEnabled,
                        compactLayout: mode == .compact
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if mode == .expanded {
                        Divider()
                        RightInspectorView(selectedTab: $selectedAuditTab)
                            .frame(width: 300)
                    }
                }
            }
            .sheet(isPresented: $showVolumes) {
                sidebar
                    .frame(minWidth: 320, minHeight: 500)
            }
            .sheet(isPresented: $showAudit) {
                VStack(spacing: 0) {
                    HStack {
                        Text(langManager.text("历史操作审计", "Operation Audit History"))
                            .font(.headline)
                        Spacer()
                        Button {
                            showAudit = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    Divider()
                    RightInspectorView(selectedTab: $selectedAuditTab)
                        .frame(minWidth: 360, minHeight: 500)
                }
            }
            .onAppear { synchronizeSelection() }
            .onChange(of: monitor.volumes) { _, _ in synchronizeSelection() }
            .onChange(of: ignoredVolumes.paths) { _, _ in synchronizeSelection() }
        }
    }

    private var sidebar: some View {
        SidebarView(
            monitor: monitor,
            selectedVolume: $selectedVolume,
            isAutoRenameEnabled: $isAutoRenameEnabled,
            onShowAbout: onShowAbout,
            onShowSettings: onShowSettings
        )
    }

    private func compactToolbar(mode: WorkspaceLayoutMode) -> some View {
        HStack(spacing: 10) {
            if mode == .compact {
                Button {
                    showVolumes = true
                } label: {
                    Label(langManager.text("存储卡", "Cards"), systemImage: "sdcard")
                }
                .buttonStyle(.borderless)
            }

            Spacer()

            Text(selectedVolume?.name ?? langManager.text("未选择存储卡", "No card selected"))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            Button {
                showAudit = true
            } label: {
                Label(langManager.text("审计", "Audit"), systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
    }

    private func synchronizeSelection() {
        let active = monitor.volumes.filter { !ignoredVolumes.paths.contains($0.path) }
        if let selectedVolume, active.contains(where: { $0.id == selectedVolume.id }) {
            return
        }
        selectedVolume = active.first
    }
}

private enum WorkspaceLayoutMode: Equatable {
    case expanded
    case standard
    case compact

    static func resolve(width: CGFloat) -> WorkspaceLayoutMode {
        if width >= 1180 { return .expanded }
        if width >= 900 { return .standard }
        return .compact
    }
}

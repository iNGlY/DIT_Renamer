// Copyright 2026 DIT247
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import AppKit

// Native NSVisualEffectView Wrapper for Global macOS Glassmorphism
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .fullScreenUI
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

@main
struct DITRenamerApp: App {
    @StateObject private var volumeMonitor = VolumeMonitor()
    @StateObject private var updateController = UpdateController.shared
    @ObservedObject private var langManager = LanguageManager.shared
    
    @State private var selectedVolume: MountedVolume? = nil
    @State private var isAutoRenameEnabled: Bool = false
    @State private var selectedAuditTab: AuditTab = .rename
    @State private var showAboutSheet: Bool = false
    @State private var showParaShootSheet: Bool = false
    @State private var showSettingsSheet: Bool = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Global Full-Window Glassmorphic Material
                VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                
                HStack(spacing: 0) {
                    // Left Sidebar (Frosted Glass)
                    SidebarView(
                        monitor: volumeMonitor,
                        selectedVolume: $selectedVolume,
                        isAutoRenameEnabled: $isAutoRenameEnabled,
                        onShowAbout: { showAboutSheet = true },
                        onShowSettings: { showSettingsSheet = true }
                    )
                    
                    Divider()
                    
                    // Main Workspace (Responsive Glass)
                    MainDetailView(
                        volume: $selectedVolume,
                        monitor: volumeMonitor,
                        isAutoRenameEnabled: $isAutoRenameEnabled
                    )
                    
                    Divider()
                    
                    // Permanent Fixed Right Audit Inspector Sidebar
                    RightInspectorView(selectedTab: $selectedAuditTab)
                }
            }
            .frame(minWidth: 1180, idealWidth: 1180, minHeight: 680, idealHeight: 680)
            .preferredColorScheme(.dark)
            .onAppear {
                LegacyAppMigrator.shared.migrateIfNeeded()
            }
            .alert(item: $updateController.startupNotice) { notice in
                Alert(
                    title: Text(notice.title),
                    message: Text(notice.message),
                    dismissButton: .default(Text(notice.actionTitle ?? langManager.text("知道了", "OK"))) {
                        if let actionURL = notice.actionURL {
                            NSWorkspace.shared.open(actionURL)
                        }
                    }
                )
            }
            .sheet(isPresented: $showAboutSheet) {
                AboutView()
            }
            .sheet(isPresented: $showParaShootSheet) {
                ParaShootAuditView()
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(monitor: volumeMonitor)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 680)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(langManager.text("关于 DIT Renamer", "About DIT Renamer")) {
                    showAboutSheet = true
                }
            }
            CommandGroup(after: .appInfo) {
                Button(langManager.text("检查更新…", "Check for Updates…")) {
                    updateController.checkForUpdates()
                }
                .disabled(!updateController.canCheckForUpdates)
            }
        }
    }
}

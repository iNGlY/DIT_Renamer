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
    @Environment(\.openWindow) private var openWindow
    @StateObject private var runtime: AppRuntime
    @StateObject private var approvalCoordinator = RenameApprovalCoordinator.shared
    @StateObject private var updateController = UpdateController.shared
    @StateObject private var attentionCenter = OperatorAttentionCenter.shared
    @ObservedObject private var langManager = LanguageManager.shared
    
    @State private var selectedVolume: MountedVolume? = nil
    @AppStorage("menuBarAutoRenameEnabled") private var isAutoRenameEnabled: Bool = false
    @State private var selectedAuditTab: AuditTab = .rename
    @State private var showAboutSheet: Bool = false
    @State private var showParaShootSheet: Bool = false
    @State private var showSettingsSheet: Bool = false

    init() {
        let runtime = AppRuntime()
        _runtime = StateObject(wrappedValue: runtime)
    }

    var body: some Scene {
        Window("DIT Renamer", id: "main") {
            ZStack {
                // Global Full-Window Glassmorphic Material
                VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                
                ResponsiveWorkspaceView(
                    monitor: runtime.volumeMonitor,
                    ignoredVolumes: runtime.ignoredVolumes,
                    selectedVolume: $selectedVolume,
                    isAutoRenameEnabled: $isAutoRenameEnabled,
                    selectedAuditTab: $selectedAuditTab,
                    onShowSettings: { showSettingsSheet = true },
                    onShowAbout: { showAboutSheet = true }
                )
            }
            .background(MainWindowAccessor())
            .frame(minWidth: 720, idealWidth: 1180, minHeight: 520, idealHeight: 680)
            .preferredColorScheme(.dark)
            .onAppear {
                LegacyAppMigrator.shared.migrateIfNeeded()
                MainWindowCoordinator.shared.configure {
                    openWindow(id: "main")
                }
            }
            .sheet(isPresented: $showAboutSheet) {
                AboutView()
            }
            .sheet(isPresented: $showParaShootSheet) {
                ParaShootAuditView()
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(monitor: runtime.volumeMonitor)
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
                    updateController.performUserUpdateAction()
                }
                .disabled(!updateController.canCheckForUpdates || MediaOperationCoordinator.shared.isBusy)
            }
        }

        MenuBarExtra {
            RenameMenuBarView(
                coordinator: approvalCoordinator,
                runtime: runtime,
                attentionCenter: attentionCenter,
                onShowSettings: {
                    openMainWindow()
                    DispatchQueue.main.async { showSettingsSheet = true }
                },
                onShowAbout: {
                    openMainWindow()
                    DispatchQueue.main.async { showAboutSheet = true }
                },
                openMainWindow: {
                    openMainWindow()
                }
            )
        } label: {
            HStack(spacing: 3) {
                Image(systemName: approvalCoordinator.pendingCount > 0
                      ? "sdcard.fill"
                      : "sdcard")
                if approvalCoordinator.pendingCount > 0 {
                    Text("\(approvalCoordinator.pendingCount)")
                        .font(.caption2)
                }
            }
            .accessibilityLabel(langManager.text(
                approvalCoordinator.pendingCount > 0
                    ? "DIT Renamer，\(approvalCoordinator.pendingCount) 张卡待审核"
                    : "DIT Renamer，没有待审核卡片",
                approvalCoordinator.pendingCount > 0
                    ? "DIT Renamer, \(approvalCoordinator.pendingCount) cards awaiting review"
                    : "DIT Renamer, no cards awaiting review"
            ))
        }
        .menuBarExtraStyle(.window)
    }

    private func openMainWindow() {
        MainWindowCoordinator.shared.show()
    }
}

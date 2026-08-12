// Copyright 2026 DIT247
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct UpdateActionButton: View {
    @ObservedObject private var updateController = UpdateController.shared
    @ObservedObject private var mediaOperations = MediaOperationCoordinator.shared
    @ObservedObject private var langManager = LanguageManager.shared

    var compact = false

    var body: some View {
        Button {
            updateController.performUserUpdateAction()
        } label: {
            HStack(spacing: 6) {
                if updateController.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: updateController.availableVersion == nil
                          ? "arrow.triangle.2.circlepath"
                          : "arrow.down.circle.fill")
                }

                if !compact || updateController.availableVersion != nil {
                    Text(buttonTitle)
                        .lineLimit(1)
                }
            }
        }
        .disabled(!updateController.canCheckForUpdates || mediaOperations.isBusy)
        .help(helpText)
        .accessibilityLabel(buttonTitle)
    }

    private var buttonTitle: String {
        if let version = updateController.availableVersion {
            return langManager.text("更新到 \(version)", "Update to \(version)")
        }
        if updateController.isChecking {
            return langManager.text("正在检查…", "Checking…")
        }
        return langManager.text("检查更新…", "Check for Updates…")
    }

    private var helpText: String {
        if mediaOperations.isBusy {
            return langManager.text(
                "存储卡操作完成后才能检查或安装更新。",
                "Updates are available after the current card operation finishes."
            )
        }
        if updateController.availableVersion != nil {
            return langManager.text(
                "查看更新内容并确认是否安装。",
                "Review release notes and confirm whether to install."
            )
        }
        return langManager.text("检查 GitHub Release 中的新版本。", "Check GitHub Releases for a newer version.")
    }
}

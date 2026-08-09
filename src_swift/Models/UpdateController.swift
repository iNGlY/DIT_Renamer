// Copyright 2026 DIT247
// SPDX-License-Identifier: Apache-2.0

import AppKit
import Combine
import Foundation
import Sparkle

@MainActor
final class MediaOperationCoordinator: ObservableObject {
    static let shared = MediaOperationCoordinator()

    @Published private(set) var isBusy = false
    private var activeOperations = 0

    func beginOperation() {
        activeOperations += 1
        isBusy = true
    }

    func endOperation() {
        activeOperations = max(0, activeOperations - 1)
        isBusy = activeOperations > 0
    }
}

struct UpdateNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let actionTitle: String?
    let actionURL: URL?
}

enum DITRenamerAppInfo {
    static let bundleIdentifier = "com.dit.renamer.release"
    static let stableApplicationName = "DIT Renamer.app"
    static let updateFeedURL = URL(string: "https://ingly.github.io/DIT_Renamer/appcast.xml")!

    static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.1"
    }

    static var buildVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? shortVersion
    }
}

private struct PendingUpdate: Codable {
    let targetBuild: String
    let targetDisplayVersion: String
    let recordedAt: Date
}

@MainActor
final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateController()

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var isChecking = false
    @Published var startupNotice: UpdateNotice?

    private(set) lazy var updaterController: SPUStandardUpdaterController = {
        SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }()

    private var didScheduleLaunchCheck = false
    private var canCheckObservation: AnyCancellable?
    private let defaults = UserDefaults.standard
    private let lastCheckKey = "DITRenamer.UpdateController.lastLaunchCheck"
    private let pendingUpdateKey = "DITRenamer.UpdateController.pendingUpdate"
    private let launchCheckInterval: TimeInterval = 86_400

    override init() {
        super.init()
        _ = updaterController
        canCheckObservation = updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] canCheck in
                self?.canCheckForUpdates = canCheck
            }
        validatePendingUpdate()
        scheduleLaunchCheck()
    }

    func checkForUpdates() {
        guard updaterController.updater.canCheckForUpdates else { return }
        updaterController.updater.checkForUpdates()
    }

    private func scheduleLaunchCheck() {
        guard !didScheduleLaunchCheck else { return }
        didScheduleLaunchCheck = true

        let lastCheck = defaults.object(forKey: lastCheckKey) as? Date
        guard lastCheck == nil || Date().timeIntervalSince(lastCheck!) >= launchCheckInterval else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, !MediaOperationCoordinator.shared.isBusy else { return }
            self.defaults.set(Date(), forKey: self.lastCheckKey)
            self.isChecking = true
            self.updaterController.updater.checkForUpdatesInBackground()
        }
    }

    private func validatePendingUpdate() {
        guard let data = defaults.data(forKey: pendingUpdateKey),
              let pending = try? JSONDecoder().decode(PendingUpdate.self, from: data) else { return }

        let comparison = compareVersions(DITRenamerAppInfo.buildVersion, pending.targetBuild)
        if comparison == .orderedSame || comparison == .orderedDescending {
            defaults.removeObject(forKey: pendingUpdateKey)
            return
        }

        startupNotice = UpdateNotice(
            title: LanguageManager.shared.text("更新未完成", "Update did not complete"),
            message: LanguageManager.shared.text(
                "目标版本 \(pending.targetDisplayVersion) 未成功启动，当前版本为 \(DITRenamerAppInfo.shortVersion)。旧版本未被删除。",
                "Version \(pending.targetDisplayVersion) did not start successfully. The current version is \(DITRenamerAppInfo.shortVersion). The previous version was not removed."
            ),
            actionTitle: LanguageManager.shared.text("打开发布页", "Open Releases"),
            actionURL: URL(string: "https://github.com/iNGlY/DIT_Renamer/releases/latest")
        )
    }

    private func writePendingUpdate(for item: SUAppcastItem) {
        let pending = PendingUpdate(
            targetBuild: item.versionString,
            targetDisplayVersion: item.displayVersionString,
            recordedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(pending) else { return }
        defaults.set(data, forKey: pendingUpdateKey)
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate updateItem: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        guard !MediaOperationCoordinator.shared.isBusy else {
            throw NSError(
                domain: "com.dit.renamer.update",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: LanguageManager.shared.text(
                    "当前正在处理存储卡，更新已暂停。请在重命名和重挂载完成后再次检查更新。",
                    "A card operation is in progress. The update is paused; check again after renaming and remounting finish."
                )]
            )
        }
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        isChecking = false
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        isChecking = false
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        isChecking = false
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        writePendingUpdate(for: item)
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        isChecking = false
        if error != nil {
            defaults.removeObject(forKey: pendingUpdateKey)
        }
    }
}

@MainActor
final class LegacyAppMigrator {
    static let shared = LegacyAppMigrator()

    private let completedKey = "DITRenamer.LegacyAppMigrator.completed"

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: completedKey),
              !Bundle.main.bundleURL.path.isEmpty else { return }
        let currentURL = Bundle.main.bundleURL.standardizedFileURL
        guard currentURL.lastPathComponent == DITRenamerAppInfo.stableApplicationName,
              isSupportedInstallDirectory(currentURL.deletingLastPathComponent()) else { return }

        let parent = currentURL.deletingLastPathComponent()
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: parent,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var hadAmbiguousCandidate = false
        for candidate in entries where candidate.pathExtension.lowercased() == "app" {
            guard candidate != currentURL,
                  candidate.lastPathComponent.hasPrefix("dit_renamer_Release_") else { continue }
            guard let candidateBundle = Bundle(url: candidate),
                  candidateBundle.bundleIdentifier == DITRenamerAppInfo.bundleIdentifier else {
                hadAmbiguousCandidate = true
                continue
            }
            guard let candidateBuild = candidateBundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                  compareVersions(candidateBuild, DITRenamerAppInfo.buildVersion) == .orderedAscending else { continue }
            if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleURL?.standardizedFileURL == candidate }) {
                hadAmbiguousCandidate = true
                continue
            }

            do {
                try FileManager.default.trashItem(at: candidate, resultingItemURL: nil)
            } catch {
                hadAmbiguousCandidate = true
            }
        }

        if !hadAmbiguousCandidate {
            UserDefaults.standard.set(true, forKey: completedKey)
        }
    }

    private func isSupportedInstallDirectory(_ url: URL) -> Bool {
        let path = url.path
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true).path
        return path == "/Applications" || path == userApplications
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}

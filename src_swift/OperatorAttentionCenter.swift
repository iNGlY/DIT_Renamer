import AppKit
import CryptoKit
import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class MainWindowCoordinator: ObservableObject {
    static let shared = MainWindowCoordinator()

    @Published private(set) var isVisible = false

    private weak var window: NSWindow?
    private var openHandler: (() -> Void)?
    private var didApplyLaunchPolicy = false
    private var presentationRequested = false

    private init() {}

    func configure(openHandler: @escaping () -> Void) {
        self.openHandler = openHandler
    }

    func register(window: NSWindow) {
        if self.window === window { return }
        self.window = window
        window.setFrameAutosaveName("DITRenamerMainWindow")
        observeVisibility(of: window)

        guard !didApplyLaunchPolicy else { return }
        didApplyLaunchPolicy = true
        let startsInBackground = UserDefaults.standard.object(forKey: "startInBackground") as? Bool ?? true
        if startsInBackground && !presentationRequested {
            DispatchQueue.main.async {
                window.orderOut(nil)
                self.isVisible = false
            }
        }
    }

    func show() {
        presentationRequested = true
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            isVisible = true
            return
        }

        openHandler?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            self.window?.makeKeyAndOrderFront(nil)
            self.isVisible = self.window?.isVisible == true
        }
    }

    func hide() {
        window?.orderOut(nil)
        isVisible = false
    }

    private func observeVisibility(of window: NSWindow) {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isVisible = true }
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            Task { @MainActor in self?.isVisible = window?.isVisible == true }
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.window = nil
                self?.isVisible = false
            }
        }
    }
}

struct MainWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                MainWindowCoordinator.shared.register(window: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                MainWindowCoordinator.shared.register(window: window)
            }
        }
    }
}

@MainActor
final class OperatorAttentionCenter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = OperatorAttentionCenter()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastStatusText: String?

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let knownIdentitiesKey = "DITRenamer.OperatorAttention.knownReviewIdentities"
    private var activeCandidateIDs: [UUID: RenameCandidate] = [:]

    private override init() {
        super.init()
        center.delegate = self
    }

    var notificationsEnabled: Bool {
        defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
    }

    var showMainWindowForReview: Bool {
        defaults.bool(forKey: "showMainWindowForReview")
    }

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in
                self.lastStatusText = granted
                    ? LanguageManager.shared.text("系统通知已启用。", "System notifications are enabled.")
                    : LanguageManager.shared.text("系统通知未获授权，待办仍会显示在菜单栏。", "Notifications are unavailable; reviews remain visible in the menu bar.")
                self.refreshAuthorizationStatus()
            }
        }
    }

    func reconcile(candidates: [RenameCandidate]) {
        activeCandidateIDs = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        let activeIdentities = Set(candidates.map(\.identityKey))
        var known = knownIdentities
        let resolved = known.subtracting(activeIdentities)
        if !resolved.isEmpty {
            known.subtract(resolved)
            saveKnownIdentities(known)
            let identifiers = resolved.map(notificationIdentifier)
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }

        let automatic = defaults.bool(forKey: "menuBarAutoRenameEnabled")
        for candidate in candidates where !known.contains(candidate.identityKey) {
            known.insert(candidate.identityKey)
            if automatic && candidate.canBeBatchApproved { continue }
            notifyReviewRequired(candidate)
        }
        saveKnownIdentities(known)
    }

    func record(result: RenameExecutionResult) {
        guard !result.success else {
            lastStatusText = result.message
            return
        }
        lastStatusText = result.message
        guard !MainWindowCoordinator.shared.isVisible,
              let candidate = activeCandidateIDs[result.candidateID] else { return }
        notifyFailure(candidate: candidate, message: result.message)
    }

    private func notifyReviewRequired(_ candidate: RenameCandidate) {
        if showMainWindowForReview {
            MainWindowCoordinator.shared.show()
        }
        guard notificationsEnabled else { return }

        withNotificationAuthorization { authorized in
            guard authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = LanguageManager.shared.text("存储卡需要确认", "Camera Card Needs Review")
            content.body = LanguageManager.shared.text(
                "\(candidate.originalName) 已完成扫描，建议卷名为 \(candidate.effectiveName ?? "—")。可在菜单栏中批准或手动指派。",
                "\(candidate.originalName) finished scanning. Suggested name: \(candidate.effectiveName ?? "—"). Approve or assign it from the menu bar."
            )
            content.sound = .default
            content.userInfo = ["candidateID": candidate.id.uuidString]
            let request = UNNotificationRequest(
                identifier: self.notificationIdentifier(candidate.identityKey),
                content: content,
                trigger: nil
            )
            self.center.add(request)
        }
    }

    private func notifyFailure(candidate: RenameCandidate, message: String) {
        guard notificationsEnabled else { return }
        withNotificationAuthorization { authorized in
            guard authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = LanguageManager.shared.text("存储卡操作失败", "Camera Card Operation Failed")
            content.body = "\(candidate.originalName): \(message)"
            content.sound = .default
            content.userInfo = ["candidateID": candidate.id.uuidString]
            self.center.add(UNNotificationRequest(
                identifier: "failure.\(candidate.id.uuidString)",
                content: content,
                trigger: nil
            ))
        }
    }

    private func withNotificationAuthorization(_ completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    completion(true)
                case .notDetermined:
                    Task {
                        let granted = (try? await self.center.requestAuthorization(options: [.alert, .sound])) ?? false
                        await MainActor.run {
                            self.refreshAuthorizationStatus()
                            completion(granted)
                        }
                    }
                case .denied:
                    completion(false)
                @unknown default:
                    completion(false)
                }
            }
        }
    }

    private var knownIdentities: Set<String> {
        Set(defaults.stringArray(forKey: knownIdentitiesKey) ?? [])
    }

    private func saveKnownIdentities(_ identities: Set<String>) {
        defaults.set(Array(identities).sorted(), forKey: knownIdentitiesKey)
    }

    private func notificationIdentifier(_ identity: String) -> String {
        let digest = SHA256.hash(data: Data(identity.utf8))
        return "review." + digest.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            completionHandler(MainWindowCoordinator.shared.isVisible ? [] : [.banner, .list, .sound])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            MainWindowCoordinator.shared.show()
            completionHandler()
        }
    }
}

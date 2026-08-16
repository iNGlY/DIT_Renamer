import AppKit
import SwiftUI
import UserNotifications

struct RenameMenuBarView: View {
    @ObservedObject var coordinator: RenameApprovalCoordinator
    @ObservedObject var runtime: AppRuntime
    @ObservedObject var attentionCenter: OperatorAttentionCenter
    @ObservedObject var langManager = LanguageManager.shared
    @ObservedObject private var updateController = UpdateController.shared

    let onShowSettings: () -> Void
    let onShowAbout: () -> Void
    let openMainWindow: () -> Void

    @AppStorage("menuBarAutoRenameEnabled") private var autoRenameEnabled = false
    @AppStorage("excludeAPFS") private var excludeAPFS = true
    @AppStorage("excludeNTFS") private var excludeNTFS = true
    @AppStorage("excludeUDF") private var excludeUDF = true
    @AppStorage("excludeHDECodex") private var excludeCodex = true
    @AppStorage("enableExifToolModelDetection") private var enableExifToolModelDetection = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("showMainWindowForReview") private var showMainWindowForReview = false

    @State private var selectedSection: MenuSection = .cards
    @State private var selectedCandidateID: UUID?
    @State private var showBatchConfirmation = false
    @State private var notice: String?
    @State private var cameraLetter = "A"
    @State private var rollNumber = "001"
    @State private var reuseCount = ""
    @State private var includeReuseCount = false
    @State private var duplicateCameraID = false
    @State private var includeSuffix = true
    @State private var pendingStandardRename: StandardRenameConfirmation?

    private enum MenuSection: String, CaseIterable, Identifiable {
        case cards
        case review
        case rules
        case more

        var id: String { rawValue }
    }

    private struct StandardRenameConfirmation: Identifiable {
        enum Action {
            case approveSuggested
            case assign(VolumeNameRequest)
        }

        let id = UUID()
        let candidateID: UUID
        let originalName: String
        let action: Action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            controlStrip

            Picker("", selection: $selectedSection) {
                Text(langManager.text("卡片", "Cards")).tag(MenuSection.cards)
                Text(reviewTabTitle).tag(MenuSection.review)
                Text(langManager.text("规则", "Rules")).tag(MenuSection.rules)
                Text(langManager.text("更多", "More")).tag(MenuSection.more)
            }
            .pickerStyle(.segmented)

            Divider()

            ScrollView {
                Group {
                    switch selectedSection {
                    case .cards:
                        cardsSection
                    case .review:
                        reviewSection
                    case .rules:
                        rulesSection
                    case .more:
                        moreSection
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 180, maxHeight: 480)

            if let status = notice ?? attentionCenter.lastStatusText {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 450)
        .onAppear {
            if coordinator.pendingCount > 0 { selectedSection = .review }
            attentionCenter.refreshAuthorizationStatus()
        }
        .onChange(of: coordinator.pendingCount) { _, newValue in
            if newValue > 0 { selectedSection = .review }
        }
        .confirmationDialog(
            langManager.text("确认批量批准？", "Approve all selected cards?"),
            isPresented: $showBatchConfirmation,
            titleVisibility: .visible
        ) {
            Button(langManager.text("批准并逐张执行", "Approve and process sequentially")) {
                Task {
                    let results = await coordinator.approveBatch()
                    let successful = results.filter(\.success).count
                    notice = langManager.text(
                        "已完成 \(successful)/\(results.count) 张卡的批准。",
                        "Completed \(successful) of \(results.count) approvals."
                    )
                }
            }
            Button(langManager.text("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(langManager.text(
                "系统会逐张复核 UUID、强制卸载并重新挂载；首项失败后停止。",
                "Cards are processed sequentially with UUID revalidation and forced remounting; the batch stops after the first failure."
            ))
        }
        .alert(item: $pendingStandardRename) { confirmation in
            Alert(
                title: Text(langManager.text("确认覆盖规范卷名？", "Overwrite Standard Volume Name?")),
                message: Text(langManager.text(
                    "当前卷名 \(confirmation.originalName) 已符合摄影机规范命名格式。继续操作会覆盖摄影机生成的卷名，请确认这是有意的手动操作。",
                    "The current volume name \(confirmation.originalName) already follows a camera naming convention. Continuing will overwrite the camera-generated name."
                )),
                primaryButton: .destructive(Text(langManager.text("确认重命名", "Rename Anyway"))) {
                    performConfirmedRename(confirmation)
                },
                secondaryButton: .cancel(Text(langManager.text("取消", "Cancel")))
            )
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: coordinator.pendingCount > 0 ? "sdcard.fill" : "sdcard")
                .foregroundColor(coordinator.pendingCount > 0 ? .orange : .blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("DIT Renamer").font(.headline)
                Text(langManager.text(
                    coordinator.pendingCount > 0 ? "\(coordinator.pendingCount) 张卡待人工处理" : "后台监控中",
                    coordinator.pendingCount > 0 ? "\(coordinator.pendingCount) card(s) awaiting review" : "Monitoring in background"
                ))
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            if coordinator.isScanning { ProgressView().controlSize(.small) }
        }
    }

    private var controlStrip: some View {
        HStack(spacing: 10) {
            Toggle(langManager.text("自动重命名", "Auto Rename"), isOn: $autoRenameEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .help(langManager.text(
                    "仅自动处理完整、高置信度候选，并执行强制卸载和重挂载。",
                    "Only complete, high-confidence candidates are renamed and force-remounted automatically."
                ))
            Spacer()
            Button {
                runtime.refreshAll()
                notice = langManager.text("已开始重新扫描。", "Rescan started.")
            } label: {
                Label(langManager.text("刷新", "Refresh"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(MediaOperationCoordinator.shared.isBusy)
        }
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if runtime.volumeMonitor.volumes.isEmpty {
                emptyMessage(icon: "externaldrive.badge.minus", text: langManager.text("未检测到可处理的存储卡", "No eligible camera cards detected"))
            } else {
                ForEach(runtime.volumeMonitor.volumes) { volume in
                    let ignored = runtime.ignoredVolumes.isIgnored(volume)
                    HStack(spacing: 8) {
                        Image(systemName: ignored ? "eye.slash" : (volume.isGenericName ? "sdcard" : "sdcard.fill"))
                            .foregroundColor(ignored ? .secondary : .blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(volume.name).fontWeight(.semibold).lineLimit(1)
                            Text("/dev/\(volume.bsdNode) · \(volume.fileSystem) · \(volume.usedGBFormatted)")
                                .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                            if volume.isReadOnly {
                                Text(langManager.text("只读分析", "Read-only inspection"))
                                    .font(.caption2).foregroundColor(.orange)
                            } else if !volume.canAutomaticallyRename {
                                Text(langManager.text("可手动重命名 · 自动与批量已关闭", "Manual rename available · Auto and batch disabled"))
                                    .font(.caption2).foregroundColor(.yellow)
                            }
                        }
                        Spacer()
                        Button(ignored ? langManager.text("恢复", "Restore") : langManager.text("忽略", "Ignore")) {
                            runtime.ignoredVolumes.setIgnored(!ignored, volume: volume)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(9)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if coordinator.pendingCandidates.isEmpty {
                emptyMessage(icon: "checkmark.seal", text: langManager.text("当前没有待审核卡片", "No cards need review"))
            } else {
                ForEach(coordinator.pendingCandidates) { candidate in
                    candidateRow(candidate)
                }
            }

            if !coordinator.batchCandidates.isEmpty {
                Button {
                    showBatchConfirmation = true
                } label: {
                    Label(
                        langManager.text(
                            "批量批准 \(coordinator.batchCandidates.count) 张高置信度卡",
                            "Approve \(coordinator.batchCandidates.count) high-confidence cards"
                        ),
                        systemImage: "checkmark.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(coordinator.isScanning || MediaOperationCoordinator.shared.isBusy)
            }

            if let selectedCandidate {
                assignmentPanel(for: selectedCandidate)
            }
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ruleToggle(langManager.text("排除 APFS", "Exclude APFS"), binding: $excludeAPFS)
            ruleToggle(langManager.text("排除 NTFS", "Exclude NTFS"), binding: $excludeNTFS)
            ruleToggle(langManager.text("排除 UDF 摄影机卷", "Exclude UDF camera volumes"), binding: $excludeUDF)
            ruleToggle(langManager.text("排除 Codex HDE / X2XFUSE", "Exclude Codex HDE / X2XFUSE"), binding: $excludeCodex)
            ruleToggle(langManager.text("允许 exiftool 型号识别", "Enable exiftool model detection"), binding: $enableExifToolModelDetection)

            Divider()
            Label(
                langManager.text(
                    "Apple Disk Image Media、SMBFS、AUTOFS 与 DEVFS 始终排除。",
                    "Apple Disk Image Media, SMBFS, AUTOFS, and DEVFS are always excluded."
                ),
                systemImage: "lock.fill"
            )
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            if MediaScanner.exifToolPath == nil {
                Label(
                    langManager.text("exiftool 未安装；Sidecar/XML 识别仍可正常工作。", "exiftool is not installed; sidecar/XML detection still works."),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundColor(.orange)
            }
        }
    }

    private var moreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(langManager.text("需要人工确认时发送通知", "Notify when review is required"), isOn: $notificationsEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Toggle(langManager.text("需要确认时自动显示主窗口", "Show main window when review is required"), isOn: $showMainWindowForReview)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                HStack {
                    notificationStatus
                    Spacer()
                    if attentionCenter.authorizationStatus == .notDetermined {
                        Button(langManager.text("启用通知", "Enable")) {
                            attentionCenter.requestAuthorization()
                        }
                        .buttonStyle(.borderless)
                    } else if attentionCenter.authorizationStatus == .denied {
                        Button(langManager.text("系统设置", "System Settings")) {
                            openNotificationSettings()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            UpdateActionButton()
                .buttonStyle(.bordered)
                .controlSize(.small)

            if let startupNotice = updateController.startupNotice {
                VStack(alignment: .leading, spacing: 4) {
                    Label(startupNotice.title, systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Text(startupNotice.message)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let actionURL = startupNotice.actionURL {
                        Button(startupNotice.actionTitle ?? langManager.text("打开发布页", "Open Releases")) {
                            NSWorkspace.shared.open(actionURL)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button {
                langManager.currentLanguage = langManager.currentLanguage == .zh ? .en : .zh
            } label: {
                Label(langManager.currentLanguage == .zh ? "English" : "中文", systemImage: "globe")
            }
            .buttonStyle(.borderless)

            Button(action: onShowSettings) {
                Label(langManager.text("完整设置", "Full Settings"), systemImage: "gearshape")
            }
            .buttonStyle(.borderless)

            Button(action: onShowAbout) {
                Label(langManager.text("关于 DIT Renamer", "About DIT Renamer"), systemImage: "info.circle")
            }
            .buttonStyle(.borderless)

            Text("Release \(DITRenamerAppInfo.shortVersion) (\(DITRenamerAppInfo.buildVersion))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Button(langManager.text("打开主窗口与审计", "Open Main Window & Audit"), action: openMainWindow)
                .buttonStyle(.borderless)
            Spacer()
            Button(langManager.text("退出", "Quit")) {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
    }

    private var reviewTabTitle: String {
        let title = langManager.text("待办", "Review")
        return coordinator.pendingCount > 0 ? "\(title) \(coordinator.pendingCount)" : title
    }

    private var selectedCandidate: RenameCandidate? {
        guard let selectedCandidateID else { return nil }
        return coordinator.pendingCandidates.first(where: { $0.id == selectedCandidateID })
    }

    private func candidateRow(_ candidate: RenameCandidate) -> some View {
        let isAutomaticSafe = coordinator.isSafeForAutomaticApproval(candidate)
        let hasTargetConflict = coordinator.hasTargetNameConflict(for: candidate)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: isAutomaticSafe ? "checkmark.seal" : "exclamationmark.triangle")
                    .foregroundColor(isAutomaticSafe ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.originalName).font(.headline)
                    Text("\(candidate.deviceType) · /dev/\(candidate.bsdNode)")
                        .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                    if let evidence = candidate.cameraMetadataEvidence {
                        let sourceLabels = evidence.source.labels
                        let confidenceLabels = evidence.confidence.labels
                        Text(langManager.text(
                            "\(sourceLabels.zh) · \(confidenceLabels.zh)置信度",
                            "\(sourceLabels.en) · \(confidenceLabels.en) confidence"
                        ))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }
                }
                Spacer()
                if candidate.state == .approving { ProgressView().controlSize(.small) }
            }

            HStack {
                Text(candidate.effectiveName ?? langManager.text("需手动指派", "Manual assignment required"))
                    .font(.system(.body, design: .monospaced)).fontWeight(.semibold).foregroundColor(.blue)
                Spacer()
                Text(candidate.fileSystem).font(.caption2).foregroundColor(.secondary)
            }

            if let error = candidate.lastError {
                Text(error).font(.caption).foregroundColor(.red).fixedSize(horizontal: false, vertical: true)
            }

            if hasTargetConflict {
                Text(langManager.text(
                    "另一张卡也建议使用这个卷名。请先手动为其中一张指派不同卷号。",
                    "Another card has the same suggested volume name. Assign a different roll to one card first."
                ))
                .font(.caption)
                .foregroundColor(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            if !candidate.hasStableVolumeIdentity {
                Text(langManager.text(
                    "未取得标准 Volume UUID：可手动批准或指派，自动与批量执行保持关闭。",
                    "No standard Volume UUID: manual approval or assignment is available; automatic and batch execution remain disabled."
                ))
                .font(.caption)
                .foregroundColor(.yellow)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button(langManager.text("批准", "Approve")) {
                    if candidate.hasGenericOriginalName {
                        Task { notice = await coordinator.approveSuggestedName(candidateID: candidate.id).message }
                    } else {
                        pendingStandardRename = StandardRenameConfirmation(
                            candidateID: candidate.id,
                            originalName: candidate.originalName,
                            action: .approveSuggested
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(candidate.effectiveName == nil || coordinator.isScanning || candidate.state == .approving || candidate.state == .stale || hasTargetConflict || MediaOperationCoordinator.shared.isBusy)

                Button(langManager.text("手动指派", "Assign")) { prepareAssignment(candidate) }
                    .buttonStyle(.bordered)
                    .disabled(candidate.state == .stale)

                Button(langManager.text("重扫", "Rescan")) { coordinator.rescan(candidateID: candidate.id) }
                    .buttonStyle(.borderless)
                    .disabled(candidate.state == .stale)

                Button(langManager.text("暂不处理", "Dismiss")) { coordinator.dismiss(candidateID: candidate.id) }
                    .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func prepareAssignment(_ candidate: RenameCandidate) {
        selectedCandidateID = candidate.id
        let parsed = candidate.effectiveName ?? "A001"
        cameraLetter = String(parsed.prefix(1)).range(of: "^[A-Z]$", options: .regularExpression) != nil
            ? String(parsed.prefix(1)) : "A"
        let rest = String(parsed.dropFirst())
        let detectedRoll = String(rest.prefix { $0.isNumber })
        rollNumber = detectedRoll.isEmpty ? "001" : detectedRoll
        reuseCount = ""
        includeReuseCount = false
        duplicateCameraID = coordinator.hasTargetNameConflict(for: candidate)
        includeSuffix = candidate.suffix != nil
    }

    private func assignmentPanel(for candidate: RenameCandidate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(langManager.text("手动指派卷号", "Assign Volume Number")).font(.headline)
                Spacer()
                Button { selectedCandidateID = nil } label: { Image(systemName: "xmark.circle") }
                    .buttonStyle(.borderless)
            }

            HStack(spacing: 8) {
                TextField("A", text: $cameraLetter).frame(width: 44)
                TextField("001", text: $rollNumber)
            }
            .textFieldStyle(.roundedBorder)

            Toggle(langManager.text("机位号重复（自动增加 _1、_2…）", "Duplicate Camera ID (append _1, _2…)"), isOn: $duplicateCameraID)
                .toggleStyle(.switch).controlSize(.small)

            Toggle(langManager.text("记录卡片复用次数", "Record Card Reuse Count"), isOn: $includeReuseCount)
                .toggleStyle(.switch).controlSize(.small)

            if includeReuseCount {
                TextField(langManager.text("复用次数（仅审计/标签）", "Reuse count (audit/label only)"), text: $reuseCount)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle(langManager.text("保留素材后缀", "Keep media suffix"), isOn: $includeSuffix)
                .toggleStyle(.switch).controlSize(.small)

            let request = assignmentRequest(for: candidate)
            let preview = try? VolumeNameBuilder.build(request, fileSystem: candidate.fileSystem)
            Text(preview ?? langManager.text("卷名格式无效", "Invalid volume name"))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(preview == nil ? .red : .green)

            Button {
                if candidate.hasGenericOriginalName {
                    performAssignment(candidateID: candidate.id, request: request)
                } else {
                    pendingStandardRename = StandardRenameConfirmation(
                        candidateID: candidate.id,
                        originalName: candidate.originalName,
                        action: .assign(request)
                    )
                }
            } label: {
                Text(langManager.text("确认重命名并重挂载", "Rename and Remount"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(preview == nil || coordinator.isScanning || candidate.state == .stale || MediaOperationCoordinator.shared.isBusy)
        }
        .padding(10)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func assignmentRequest(for candidate: RenameCandidate) -> VolumeNameRequest {
        var request = VolumeNameRequest(
            cameraLetter: cameraLetter,
            rollNumber: rollNumber,
            reuseCount: includeReuseCount ? Int(reuseCount) : nil,
            includeReuseCount: includeReuseCount,
            duplicateIndex: nil,
            suffix: candidate.suffix,
            includeSuffix: includeSuffix
        )
        if duplicateCameraID {
            request.duplicateIndex = coordinator.nextAvailableDuplicateIndex(
                for: request,
                fileSystem: candidate.fileSystem,
                excludingCandidateID: candidate.id
            ) ?? 0
        }
        return request
    }

    private func performConfirmedRename(_ confirmation: StandardRenameConfirmation) {
        switch confirmation.action {
        case .approveSuggested:
            Task { notice = await coordinator.approveSuggestedName(candidateID: confirmation.candidateID).message }
        case .assign(let request):
            performAssignment(candidateID: confirmation.candidateID, request: request)
        }
    }

    private func performAssignment(candidateID: UUID, request: VolumeNameRequest) {
        Task {
            let result = await coordinator.assignVolumeName(candidateID: candidateID, request: request)
            notice = result.message
            if result.success { selectedCandidateID = nil }
        }
    }

    private func ruleToggle(_ title: String, binding: Binding<Bool>) -> some View {
        Toggle(title, isOn: binding)
            .toggleStyle(.switch)
            .controlSize(.small)
            .onChange(of: binding.wrappedValue) { _, _ in runtime.refreshFilters() }
    }

    private var notificationStatus: some View {
        let status: String
        let color: Color
        switch attentionCenter.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            status = langManager.text("系统通知可用", "Notifications available")
            color = .green
        case .denied:
            status = langManager.text("系统通知已关闭", "Notifications disabled")
            color = .orange
        case .notDetermined:
            status = langManager.text("尚未请求通知权限", "Notification permission not requested")
            color = .secondary
        @unknown default:
            status = langManager.text("通知状态未知", "Notification status unknown")
            color = .secondary
        }
        return Label(status, systemImage: "bell")
            .font(.caption)
            .foregroundColor(color)
    }

    private func emptyMessage(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(.secondary)
            Text(text).font(.callout).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}

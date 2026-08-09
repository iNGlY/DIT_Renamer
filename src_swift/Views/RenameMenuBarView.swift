import SwiftUI

struct RenameMenuBarView: View {
    @ObservedObject var coordinator: RenameApprovalCoordinator
    @ObservedObject var langManager = LanguageManager.shared
    let openMainWindow: () -> Void

    @AppStorage("menuBarAutoRenameEnabled") private var autoRenameEnabled = false
    @State private var selectedCandidateID: UUID?
    @State private var showBatchConfirmation = false
    @State private var notice: String?
    @State private var cameraLetter = "A"
    @State private var rollNumber = "001"
    @State private var reuseCount = "0"
    @State private var includeSuffix = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Toggle(
                langManager.text("允许菜单栏自动重命名", "Allow menu-bar auto-rename"),
                isOn: $autoRenameEnabled
            )
            .toggleStyle(.switch)
            .controlSize(.small)
            .help(langManager.text(
                "仅处理高置信度、通过全部安全规则的候选卡。",
                "Only high-confidence candidates that pass every safety rule are processed."
            ))

            Divider()

            if coordinator.pendingCandidates.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(coordinator.pendingCandidates) { candidate in
                            candidateRow(candidate)
                        }
                    }
                }
                .frame(maxHeight: 300)
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
                        systemImage: "checkmark.circle.badge.checkmark"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(MediaOperationCoordinator.shared.isBusy)
            }

            if let selectedCandidate {
                assignmentPanel(for: selectedCandidate)
            }

            if let notice {
                Text(notice)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            Divider()

            HStack {
                Button(langManager.text("重新扫描", "Rescan")) {
                    openMainWindow()
                }
                .buttonStyle(.borderless)

                Spacer()

                Button(langManager.text("打开主窗口", "Open Main Window")) {
                    openMainWindow()
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .frame(width: 390)
        .confirmationDialog(
            langManager.text("确认批量批准？", "Approve all selected cards?"),
            isPresented: $showBatchConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                langManager.text("批准并逐张执行", "Approve and process sequentially"),
                role: .destructive
            ) {
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
                "系统会按顺序执行，每张卡都会重新校验 UUID，并强制卸载和重挂载。任一张卡失败后停止后续批量操作。",
                "Cards run sequentially. Each card revalidates its UUID and is force-unmounted and remounted. The batch stops at the first failure."
            ))
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "externaldrive.fill.badge.checkmark")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("DIT Renamer")
                    .font(.headline)
                Text(langManager.text(
                    "\(coordinator.pendingCount) 张卡待人工处理",
                    "\(coordinator.pendingCount) card(s) awaiting review"
                ))
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            if coordinator.isScanning {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal")
                .font(.title2)
                .foregroundColor(.green)
            Text(langManager.text("当前没有待审核卡片", "No cards need review"))
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 90)
    }

    private func candidateRow(_ candidate: RenameCandidate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: candidate.canBeBatchApproved ? "checkmark.seal" : "exclamationmark.triangle")
                    .foregroundColor(candidate.canBeBatchApproved ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.originalName)
                        .font(.headline)
                    Text("\(candidate.deviceType) · /dev/\(candidate.bsdNode)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if candidate.state == .approving {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack {
                Text(candidate.effectiveName ?? langManager.text("需手动指派", "Manual assignment required"))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                Spacer()
                Text(candidate.fileSystem)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Button(langManager.text("批准", "Approve")) {
                    Task {
                        let result = await coordinator.approveSuggestedName(candidateID: candidate.id)
                        notice = result.message
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(candidate.effectiveName == nil || candidate.state == .approving || MediaOperationCoordinator.shared.isBusy)

                Button(langManager.text("手动指派", "Assign")) {
                    prepareAssignment(candidate)
                }
                .buttonStyle(.bordered)

                Button(langManager.text("忽略", "Dismiss")) {
                    coordinator.dismiss(candidateID: candidate.id)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var selectedCandidate: RenameCandidate? {
        guard let selectedCandidateID else { return nil }
        return coordinator.pendingCandidates.first(where: { $0.id == selectedCandidateID })
    }

    private func prepareAssignment(_ candidate: RenameCandidate) {
        selectedCandidateID = candidate.id
        let parsed = candidate.effectiveName ?? "A001"
        cameraLetter = String(parsed.prefix(1)).range(of: "^[A-Z]$", options: .regularExpression) != nil
            ? String(parsed.prefix(1)) : "A"
        let rest = String(parsed.dropFirst())
        rollNumber = String(rest.prefix { $0.isNumber }).isEmpty ? "001" : String(rest.prefix { $0.isNumber })
        reuseCount = "0"
        includeSuffix = candidate.suffix != nil
    }

    private func assignmentPanel(for candidate: RenameCandidate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(langManager.text("手动指派卷号", "Assign Volume Number"))
                    .font(.headline)
                Spacer()
                Button {
                    selectedCandidateID = nil
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 8) {
                TextField("A", text: $cameraLetter)
                    .frame(width: 44)
                TextField("001", text: $rollNumber)
                TextField("0", text: $reuseCount)
            }
            .textFieldStyle(.roundedBorder)

            Toggle(
                langManager.text("保留素材后缀", "Keep media suffix"),
                isOn: $includeSuffix
            )
            .toggleStyle(.switch)
            .controlSize(.small)

            let request = VolumeNameRequest(
                cameraLetter: cameraLetter,
                rollNumber: rollNumber,
                reuseCount: Int(reuseCount) ?? 0,
                suffix: candidate.suffix,
                includeSuffix: includeSuffix
            )
            let preview = try? VolumeNameBuilder.build(request, fileSystem: candidate.fileSystem)
            Text(preview ?? langManager.text("卷名格式无效", "Invalid volume name"))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(preview == nil ? .red : .green)

            Button {
                guard let candidateID = selectedCandidateID else { return }
                Task {
                    let result = await coordinator.assignVolumeName(candidateID: candidateID, request: request)
                    notice = result.message
                    if result.success { selectedCandidateID = nil }
                }
            } label: {
                Text(langManager.text("确认并重命名", "Confirm and Rename"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(preview == nil || MediaOperationCoordinator.shared.isBusy)
        }
        .padding(10)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

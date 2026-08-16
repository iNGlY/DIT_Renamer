import SwiftUI

struct MainDetailView: View {
    @ObservedObject var langManager = LanguageManager.shared
    @Binding var volume: MountedVolume?
    @ObservedObject var monitor: VolumeMonitor
    @Binding var isAutoRenameEnabled: Bool
    var compactLayout: Bool = false
    @ObservedObject private var approvalCoordinator = RenameApprovalCoordinator.shared
    
    @State private var scanResult: ScanResult? = nil
    @State private var scanVolumeID: String? = nil
    @State private var selectedLetter: String = "A"
    @State private var rollInput: String = "001"
    @State private var reuseInput: String = ""
    @State private var includeReuseCount: Bool = false
    @State private var duplicateCameraID: Bool = false
    @State private var includeDetectedSuffix: Bool = true
    @State private var alertMessage: String? = nil
    @State private var isRenaming = false
    @State private var automaticReviewReason: AutomaticRenameReviewReason?
    @State private var externalScanID: UUID?
    
    enum ActiveAlert: Identifiable {
        case confirmForce(volName: String)
        case resultNotice(message: String)
        
        var id: String {
            switch self {
            case .confirmForce(let name): return "confirmForce_\(name)"
            case .resultNotice(let msg): return "resultNotice_\(msg.hashValue)"
            }
        }
    }
    
    @State private var activeAlert: ActiveAlert? = nil
    
    let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map { String($0) }
    
    var previewNewName: String {
        builtVolumeName ?? langManager.text("卷名无效", "Invalid name")
    }

    private var builtVolumeName: String? {
        try? VolumeNameBuilder.build(currentVolumeNameRequest, fileSystem: volume?.fileSystem ?? "")
    }

    private var currentVolumeNameRequest: VolumeNameRequest {
        var request = VolumeNameRequest(
            cameraLetter: selectedLetter,
            rollNumber: rollInput,
            reuseCount: includeReuseCount ? Int(reuseInput) : nil,
            includeReuseCount: includeReuseCount,
            duplicateIndex: nil,
            suffix: scanResult?.suffix,
            includeSuffix: includeDetectedSuffix
        )
        if duplicateCameraID {
            request.duplicateIndex = approvalCoordinator.nextAvailableDuplicateIndex(
                for: request,
                fileSystem: volume?.fileSystem ?? "",
                excludingBSDNode: volume?.bsdNode
            ) ?? 0
        }
        return request
    }

    private func automaticReviewMessage(for reason: AutomaticRenameReviewReason) -> String {
        switch reason {
        case .lowConfidence:
            return langManager.text(
                "素材结构或机型识别置信度不足，已暂停自动改名，请人工确认。",
                "Camera or media-structure confidence is insufficient. Auto-rename is paused for manual review."
            )
        case .standardizedVolumeName:
            return langManager.text(
                "当前卷名已符合摄影机命名格式，已暂停自动覆盖；如需更名请人工确认。",
                "The current volume name already follows a camera naming format. Automatic overwrite is paused; confirm manually to rename it."
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(langManager.text("卡卷重命名与分析", "Volume Renaming & Analysis"))
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Text("Release \(DITRenamerAppInfo.shortVersion)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                
                // Automatic rename review notice
                if let automaticReviewReason {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text(automaticReviewMessage(for: automaticReviewReason))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.yellow)
                        Spacer()
                        Button(langManager.text("关闭", "Dismiss")) { self.automaticReviewReason = nil }
                            .font(.caption2)
                            .buttonStyle(.borderless)
                            .foregroundColor(.yellow)
                    }
                    .padding(8)
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.4), lineWidth: 1))
                }
                
                // Banner 0: Unformatted / Residual Card Warning Banner (Red Theme)
                if let res = scanResult, res.isUnformattedCard {
                    UnformattedWarningBannerView(scanResult: res)
                }
                
                // Banner 1: Unconfigured Camera Warning Banner
                if scanResult?.isUnconfiguredCamera == true {
                    UnconfiguredCameraBannerView()
                }

                // Banner 2: Optional exiftool installation notice
                if scanResult?.needsExifToolInstallation == true {
                    ExifToolInstallationBannerView()
                }
                
                // Banner 3: Empty Card Info Banner
                if scanResult?.isEmptyCard == true {
                    HStack(spacing: 8) {
                        Image(systemName: "tray")
                            .foregroundColor(.gray)
                        Text(langManager.text("这张卡中没有媒体文件，自动重命名已关闭。", "No media files were found on this card. Automatic renaming is disabled."))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)
                }
                
                // Banner 4: Photo Only Card Info Banner
                if scanResult?.isPhotoOnly == true {
                    PhotoCardBannerView(photoCount: scanResult?.photoCount ?? 0)
                }
                
                if let vol = volume {
                    VStack(alignment: .leading, spacing: 10) {
                        if vol.isReadOnly {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.orange)
                                Text(langManager.text(
                                    "该卷由 macOS 以只读方式挂载。可以浏览和分析素材，但文件系统不允许重命名。",
                                    "This volume is mounted read-only by macOS. Media can be inspected, but the file system does not allow renaming."
                                ))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            }
                            .padding(9)
                            .background(Color.orange.opacity(0.13))
                            .cornerRadius(8)
                        } else if !vol.canAutomaticallyRename {
                            HStack(spacing: 8) {
                                Image(systemName: "person.badge.key.fill")
                                    .foregroundColor(.yellow)
                                Text(langManager.text(
                                    "未取得标准 Volume UUID。仍允许手动重命名；自动重命名和批量批准保持关闭，执行前将复核 BSD 节点、挂载路径和首末素材。",
                                    "No standard Volume UUID is available. Manual renaming remains available; automatic and batch approval stay disabled, with BSD node, mount path, and media fingerprint revalidation before execution."
                                ))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.yellow)
                            }
                            .padding(9)
                            .background(Color.yellow.opacity(0.13))
                            .cornerRadius(8)
                        }

                        // Info Card
                        VStack(spacing: 6) {
                            HStack {
                                Text(langManager.text("当前盘符名称", "Current Volume Name"))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(vol.name)
                                    .fontWeight(.semibold)
                            }
                            Divider()
                            HStack {
                                Text(langManager.text("设备树路径 (BSD)", "BSD Device Tree Path"))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("/dev/\(vol.bsdNode) -> \(vol.path)")
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                            }
                            Divider()
                            HStack {
                                Text(langManager.text("存储容量", "Storage Capacity"))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(vol.freeGBFormatted) \(langManager.text("可用", "Free")) / \(vol.totalGBFormatted)")
                                    .fontWeight(.semibold)
                            }
                            Divider()
                            HStack {
                                Text(langManager.text("已用空间", "Used Space"))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(vol.usedGBFormatted)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                            Divider()
                            HStack {
                                Text(langManager.text("文件总数", "Total Files"))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(scanResult != nil ? "\(scanResult!.totalFileCount) \(langManager.text("个文件", "files"))" : langManager.text("扫描中...", "Scanning..."))
                                    .fontWeight(.semibold)
                            }
                            Divider()
                            HStack {
                                Text(langManager.text("文件系统", "File System"))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(vol.fileSystem)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        
                        // Read-only scan summary
                        ViewThatFits(in: .horizontal) {
                            HStack {
                                scanSummaryDetails
                                Spacer()
                                scanSummarySuggestion
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                scanSummaryDetails
                                scanSummarySuggestion
                            }
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                        
                        // HDE reference estimate
                        if let hde = scanResult?.hdeResult, hde.isHDESupported {
                            HDEInfoCardView(hde: hde)
                        }
                        
                        // Manual Controls
                        VStack(alignment: .leading, spacing: 10) {
                            Text(langManager.text("手动调整卷名", "Adjust Volume Name"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            let controlLayout = compactLayout
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                                : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
                            controlLayout {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(langManager.text("机位标识 (CAMERA ID)", "CAMERA ID"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: compactLayout ? 7 : 13), spacing: 4) {
                                        ForEach(letters, id: \.self) { char in
                                            Text(char)
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 4)
                                                .background(selectedLetter == char ? Color.blue : Color(NSColor.controlBackgroundColor))
                                                .foregroundColor(selectedLetter == char ? .white : .primary)
                                                .cornerRadius(5)
                                                .contentShape(Rectangle())
                                                .onTapGesture { selectedLetter = char }
                                        }
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(langManager.text("卷号 (ROLL NUMBER)", "ROLL NUMBER"))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        TextField("001", text: $rollInput)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                    
                                    Toggle(langManager.text("记录卡片复用次数", "Record Card Reuse Count"), isOn: $includeReuseCount)
                                        .toggleStyle(.switch)
                                        .controlSize(.small)

                                    if includeReuseCount {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(langManager.text("卡片复用次数（仅审计/标签）", "CARD REUSE COUNT (AUDIT/LABEL ONLY)"))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            TextField(langManager.text("留空", "Blank"), text: $reuseInput)
                                                .textFieldStyle(.roundedBorder)
                                                .font(.system(.body, design: .monospaced))
                                        }
                                    }
                                }
                                .frame(minWidth: compactLayout ? nil : 150)
                            }

                            Toggle(langManager.text("机位号重复（自动增加 _1、_2…）", "Duplicate Camera ID (append _1, _2…)"), isOn: $duplicateCameraID)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .help(langManager.text(
                                    "用于两台摄影机误用同一机位与卷号的情况；不会改变原始卷号含义。",
                                    "Use when two cameras share the same camera ID and roll; the original roll meaning is preserved."
                                ))

                            if let suffix = scanResult?.suffix {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(langManager.text("素材后缀", "MEDIA SUFFIX"))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(suffix)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $includeDetectedSuffix)
                                        .toggleStyle(.switch)
                                        .controlSize(.small)
                                        .help(langManager.text("在建议卷名中保留扫描到的素材后缀", "Keep the detected media suffix in the suggested volume name"))
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        .disabled(!vol.canAttemptManualRename)
                        .opacity(vol.canAttemptManualRename ? 1 : 0.6)
                        
                        // Volume-name preview
                        VStack(spacing: 4) {
                            Text(langManager.text("卷名预览", "Volume Name Preview"))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 12) {
                                    previewOldName(vol)
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    previewNewNameLabel
                                }
                                VStack(spacing: 4) {
                                    previewOldName(vol)
                                    Image(systemName: "arrow.down")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    previewNewNameLabel
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.3), lineWidth: 1))
                        
                        // Rename Button - Always Visible!
                        Button(action: executeRename) {
                            HStack {
                                if isRenaming {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "pencil.and.outline")
                                }
                                Text(langManager.text("重命名卷", "Rename Volume"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(vol.canAttemptManualRename ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRenaming || builtVolumeName == nil || !vol.canAttemptManualRename)
                    }
                    
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "externaldrive.badge.minus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(langManager.text("请在侧边栏选择一张存储卡", "Please select a volume from sidebar"))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 400)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startScan(for: volume) }
        .onChange(of: volume) { _, newVol in startScan(for: newVol) }
        .onChange(of: isAutoRenameEnabled) { _, enabled in
            if enabled {
                self.checkAndAutoRename()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .confirmForce(let volName):
                return Alert(
                    title: Text(langManager.text("确认强制重命名？", "Confirm Force Rename?")),
                    message: Text(langManager.text("该卡卷名称（如 \(volName)）似乎已经是标准的摄影机卷名，确定要强制覆盖重命名吗？", "This volume name (\(volName)) already appears to be a standard camera roll name. Are you sure you want to force rename?")),
                    primaryButton: .destructive(Text(langManager.text("确定覆盖", "Force Rename"))) {
                        performRename()
                    },
                    secondaryButton: .cancel(Text(langManager.text("取消", "Cancel")))
                )
            case .resultNotice(let msg):
                return Alert(
                    title: Text(langManager.text("操作提示", "Notice")),
                    message: Text(msg),
                    dismissButton: .default(Text(langManager.text("确定", "OK")))
                )
            }
        }
    }

    private var scanSummaryDetails: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                Text("\(langManager.text("素材结构分析", "Media Structure")) (\(scanResult?.deviceType ?? "Generic"))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            if let evidence = scanResult?.cameraMetadataEvidence {
                let sourceLabels = evidence.source.labels
                let confidenceLabels = evidence.confidence.labels
                Text(langManager.text(
                    "型号证据：\(sourceLabels.zh) · \(confidenceLabels.zh)置信度",
                    "Model evidence: \(sourceLabels.en) · \(confidenceLabels.en) confidence"
                ))
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            Text("\(langManager.text("首条素材", "First Clip")): \(scanResult?.firstClipName ?? langManager.text("搜索中...", "Searching..."))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("\(langManager.text("末条素材", "Last Clip")): \(scanResult?.lastClipName ?? langManager.text("搜索中...", "Searching..."))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var scanSummarySuggestion: some View {
        Text(scanResult?.suggestedName ?? langManager.text("待人工确认", "Manual confirmation required"))
            .font(.system(.title3, design: .monospaced))
            .fontWeight(.bold)
            .foregroundColor(.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.15))
            .cornerRadius(8)
    }

    private func previewOldName(_ volume: MountedVolume) -> some View {
        Text(volume.name)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.secondary)
            .lineLimit(1)
    }

    private var previewNewNameLabel: some View {
        Text(previewNewName)
            .font(.system(.title3, design: .monospaced))
            .fontWeight(.bold)
            .foregroundColor(.green)
            .lineLimit(1)
    }
    
    private func executeRename() {
        guard let vol = volume else { return }
        guard vol.canAttemptManualRename else {
            activeAlert = .resultNotice(message: langManager.text(
                "当前卷为只读或虚拟伴生卷，只能分析，无法由 macOS 执行重命名。",
                "This is a read-only or virtual companion volume. It can be inspected, but macOS cannot rename it."
            ))
            return
        }
        guard scanResult != nil, scanVolumeID == vol.id else {
            activeAlert = .resultNotice(message: langManager.text("请等待当前卡片扫描完成后再重命名。", "Wait for the selected volume scan to finish before renaming."))
            return
        }
        if vol.isUniqueCameraName {
            activeAlert = .confirmForce(volName: vol.name)
            return
        }
        performRename()
    }
    
    private func checkAndAutoRename() {
        guard let v = volume, let result = scanResult else { return }
        guard !isRenaming, v.canAutomaticallyRename, scanVolumeID == v.id, result.isScanComplete else { return }
        
        guard let targetName = builtVolumeName else { return }
        guard let candidate = approvalCoordinator.ingest(volume: v, scan: result, requestedName: targetName) else { return }

        if isAutoRenameEnabled
            && v.isGenericName
            && approvalCoordinator.isSafeForAutomaticApproval(candidate) {
            approvalCoordinator.enqueueAutomaticApproval(candidateID: candidate.id)
        }
    }

    private func performRename() {
        guard let vol = volume else { return }
        guard !isRenaming, let result = scanResult, scanVolumeID == vol.id else { return }
        guard let builtVolumeName else {
            activeAlert = .resultNotice(message: langManager.text("卷名或复用次数输入无效，请检查后重试。", "The volume name or reuse-count input is invalid. Review it and try again."))
            return
        }
        guard let candidate = approvalCoordinator.ingest(volume: vol, scan: result, requestedName: builtVolumeName) else {
            activeAlert = .resultNotice(message: langManager.text("当前卡片无法进入安全审批队列，请重新扫描后再试。", "This card could not enter the safe approval queue. Rescan it and try again."))
            return
        }
        isRenaming = true
        let request = currentVolumeNameRequest
        Task {
            let execution = await approvalCoordinator.assignVolumeName(candidateID: candidate.id, request: request)
            isRenaming = false
            if execution.success {
                volume = nil
                monitor.refreshVolumes()
            }
            activeAlert = .resultNotice(message: execution.message)
        }
    }
    
    private func startScan(for selectedVolume: MountedVolume?) {
        if let externalScanID {
            approvalCoordinator.endExternalScan(externalScanID)
            self.externalScanID = nil
        }
        scanResult = nil
        scanVolumeID = selectedVolume?.id
        includeDetectedSuffix = true
        duplicateCameraID = false
        includeReuseCount = false
        reuseInput = ""
        automaticReviewReason = nil
        guard let selectedVolume else { return }

        let volumeID = selectedVolume.id
        let registeredScanID = approvalCoordinator.beginExternalScan()
        externalScanID = registeredScanID
        DispatchQueue.global(qos: .userInitiated).async {
            let result = MediaScanner.scan(volumePath: selectedVolume.path)
            DispatchQueue.main.async {
                guard self.volume?.id == volumeID, self.scanVolumeID == volumeID else {
                    self.approvalCoordinator.endExternalScan(registeredScanID)
                    if self.externalScanID == registeredScanID { self.externalScanID = nil }
                    return
                }
                self.scanResult = result
                if let letter = result.cameraLetter { self.selectedLetter = letter }
                if let roll = result.rollNumber { self.rollInput = roll }
                self.automaticReviewReason = AutomaticRenameReviewPolicy.reason(
                    isAutoRenameEnabled: self.isAutoRenameEnabled,
                    canAutomaticallyRename: selectedVolume.canAutomaticallyRename,
                    isGenericVolumeName: selectedVolume.isGenericName,
                    isHighConfidenceScan: result.isHighConfidence
                )
                if let builtVolumeName = self.builtVolumeName {
                    _ = self.approvalCoordinator.ingest(volume: selectedVolume, scan: result, requestedName: builtVolumeName)
                }
                self.approvalCoordinator.endExternalScan(registeredScanID)
                if self.externalScanID == registeredScanID { self.externalScanID = nil }
                self.checkAndAutoRename()
            }
        }
    }
}

struct HDEInfoCardView: View {
    @ObservedObject var langManager = LanguageManager.shared
    let hde: HDEResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundColor(.purple)
                Text(langManager.text("Codex HDE 容量参考", "Codex HDE Capacity Reference"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                Spacer()
                if hde.isHDEVolumeDetected {
                    HStack(spacing: 3) {
                        Image(systemName: "externaldrive.fill.badge.checkmark")
                            .font(.system(size: 10))
                        Text(langManager.text("已检测到 HDE 卷", "HDE Volume Detected"))
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
                } else if hde.isCLIAvailable {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                        Text(langManager.text("Codex HDE CLI", "Codex HDE CLI"))
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
                } else {
                    Text(langManager.text("基于模型的参考值", "Model-based reference"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.purple.opacity(0.8))
                }
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(langManager.text("当前素材已用空间", "Used Space"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(hde.sourceGBFormatted)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                }
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(langManager.text("HDE 无损压缩后空间", "After HDE"))
                        .font(.caption2)
                        .foregroundColor(.purple)
                    Text(hde.estimatedGBFormatted)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(langManager.text("预计节省磁盘容量", "Est. Saved Space"))
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("-\(hde.savedGBFormatted) (~\(hde.compressionRatioPercent)%)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }

            if hde.isHDEVolumeDetected {
                Text(langManager.text(
                    "Codex HDE 虚拟 MXF 可能显示为 0 KB；这里按原始 ARRIRAW 素材逻辑大小和约 40% 节省的保守模型估算。",
                    "Codex HDE virtual MXF files may report 0 KB. This estimate uses the original ARRIRAW logical size and a conservative model of about 40% savings."
                ))
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.06))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.3), lineWidth: 1))
    }
}

struct UnformattedWarningBannerView: View {
    @ObservedObject var langManager = LanguageManager.shared
    let scanResult: ScanResult
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            let span = scanResult.dateSpanDays
            let earliest = scanResult.earliestDateStr ?? ""
            let latest = scanResult.latestDateStr ?? ""
            let msg = langManager.text(
                "检测到残留旧数据：卡内媒体时间跨度达 \(span) 天 (\(earliest) ~ \(latest))，疑似上场未格式化擦除，已拦截自动重命名。",
                "Residual media detected: Date span \(span) days (\(earliest) ~ \(latest)), suspected unformatted. Auto-rename blocked."
            )
            Text(msg)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.red)
        }
        .padding(10)
        .background(Color.red.opacity(0.12))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3), lineWidth: 1))
    }
}

struct UnconfiguredCameraBannerView: View {
    @ObservedObject var langManager = LanguageManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(.orange)
            let msg = langManager.text(
                "素材名仍是默认的 C0001 格式，无法确认机位。请在摄影机中设置机位，或在这里手动确认卷名。",
                "The clip name still uses the default C0001 pattern, so the camera ID cannot be confirmed. Set it in the camera or confirm the volume name manually."
            )
            Text(msg)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.orange)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }
}

struct ExifToolInstallationBannerView: View {
    @ObservedObject var langManager = LanguageManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(langManager.text(
                    "Sidecar/XML 未提供明确机型；可选的 exiftool 回退识别尚未安装。现有卷名判断不受影响。",
                    "Sidecar/XML did not provide an explicit camera model, and optional exiftool fallback detection is not installed. Existing volume-name decisions are unaffected."
                ))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)

                Text(langManager.text(
                    "手动安装：brew install exiftool；或访问 exiftool.org。",
                    "Install manually: brew install exiftool, or visit exiftool.org."
                ))
                .font(.caption2)
                .foregroundColor(.secondary)

                Link(langManager.text("打开 exiftool 官方安装页", "Open the exiftool installation page"), destination: URL(string: "https://exiftool.org/")!)
                    .font(.caption2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.blue.opacity(0.10))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.3), lineWidth: 1))
    }
}

struct PhotoCardBannerView: View {
    @ObservedObject var langManager = LanguageManager.shared
    let photoCount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .foregroundColor(.purple)
            let msg = langManager.text(
                "这张卡包含 \(photoCount) 张照片，没有视频；自动重命名已关闭。",
                "This card contains \(photoCount) photos and no video. Automatic renaming is disabled."
            )
            Text(msg)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.purple)
        }
        .padding(8)
        .background(Color.purple.opacity(0.12))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.3), lineWidth: 1))
    }
}

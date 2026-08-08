import SwiftUI

struct MainDetailView: View {
    @ObservedObject var langManager = LanguageManager.shared
    var volume: MountedVolume?
    @Binding var isAutoRenameEnabled: Bool
    
    public static var autoRenamedSessionNodes: Set<String> = []
    
    @AppStorage("renameHistoryData") private var historyData: Data = Data()
    
    @State private var scanResult: ScanResult? = nil
    @State private var selectedLetter: String = "A"
    @State private var rollInput: String = "001"
    @State private var reuseInput: String = "0"
    @State private var alertMessage: String? = nil
    @State private var isRenaming = false
    @State private var isSuspiciousWarning = false
    
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
        let reuse = Int(reuseInput) ?? 0
        var name = "\(selectedLetter)\(rollInput)"
        if reuse > 0 { name += "-\(reuse)" }
        if let suffix = scanResult?.suffix { name += suffix }
        return name
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(langManager.text("卡卷重命名与分析", "Volume Renaming & Analysis"))
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Text("Release 1.0.1")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                
                // Suspicious Device Warning Toast
                if isSuspiciousWarning {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text(langManager.text("检测到存疑设备 (Unknown Device)：已暂停自动改名，请确认后手动改名。", "Suspicious device detected: Auto-rename paused, manual review required."))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.yellow)
                        Spacer()
                        Button(langManager.text("关闭", "Dismiss")) { isSuspiciousWarning = false }
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
                
                // Banner 2: Empty Card Info Banner
                if scanResult?.isEmptyCard == true {
                    HStack(spacing: 8) {
                        Image(systemName: "tray")
                            .foregroundColor(.gray)
                        Text(langManager.text("此存储卡为空卡（无任何媒体文件），已自动保护停止重命名。", "Empty volume detected (No media files). Protected from automatic renaming."))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)
                }
                
                // Banner 3: Photo Only Card Info Banner
                if scanResult?.isPhotoOnly == true {
                    PhotoCardBannerView(photoCount: scanResult?.photoCount ?? 0)
                }
                
                if let vol = volume {
                    VStack(alignment: .leading, spacing: 10) {
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
                        
                        // AI Suggestion Box
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.blue)
                                    Text("\(langManager.text("AI 素材结构推演", "AI Media Structure Inference")) (\(scanResult?.deviceType ?? "Generic"))")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(langManager.text("首条素材", "First Clip")): \(scanResult?.firstClipName ?? langManager.text("搜索中...", "Searching..."))")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Text("\(langManager.text("末条素材", "Last Clip")): \(scanResult?.lastClipName ?? langManager.text("搜索中...", "Searching..."))")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(scanResult?.suggestedName ?? "A001")
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(8)
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                        
                        // Codex HDE Compression Engine Box
                        if let hde = scanResult?.hdeResult, hde.isHDESupported {
                            HDEInfoCardView(hde: hde, usedGBFormatted: vol.usedGBFormatted)
                        }
                        
                        // Manual Controls
                        VStack(alignment: .leading, spacing: 10) {
                            Text(langManager.text("参数手动微调", "MANUAL PARAMETERS"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(langManager.text("机位标识 (CAMERA ID)", "CAMERA ID"))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 13), spacing: 4) {
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
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(langManager.text("卡片复用次数 (REUSE COUNT)", "REUSE COUNT"))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        TextField("0", text: $reuseInput)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        
                        // Enhanced Live Preview Box (所见即所得预览)
                        VStack(spacing: 4) {
                            Text(langManager.text("所见即所得预览 (LIVE PREVIEW)", "LIVE PREVIEW"))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                Text(vol.name)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(previewNewName)
                                    .font(.system(.title3, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
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
                                Text(langManager.text("执行标准重命名", "Execute Standard Rename"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRenaming)
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
        .onChange(of: volume) { newVol in
            if let v = newVol {
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = MediaScanner.scan(volumePath: v.path)
                    DispatchQueue.main.async {
                        self.scanResult = result
                        if let letter = result.cameraLetter { self.selectedLetter = letter }
                        if let roll = result.rollNumber { self.rollInput = roll }
                        
                        if self.isAutoRenameEnabled && (!result.isHighConfidence || !v.isGenericName) {
                            self.isSuspiciousWarning = true
                        } else {
                            self.isSuspiciousWarning = false
                        }
                        
                        self.checkAndAutoRename()
                    }
                }
            }
        }
        .onChange(of: isAutoRenameEnabled) { enabled in
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
    
    private func executeRename() {
        guard let vol = volume else { return }
        if vol.isUniqueCameraName {
            activeAlert = .confirmForce(volName: vol.name)
            return
        }
        performRename()
    }
    
    private func checkAndAutoRename() {
        guard let v = volume, let result = scanResult else { return }
        
        let targetName = previewNewName
        let alreadyInHistory = RenameHistoryStore.shared.items.contains { record in
            record.newName == targetName && (result.firstClipName == nil || record.firstClipName == result.firstClipName)
        }
        
        if isAutoRenameEnabled
            && v.isGenericName
            && result.isHighConfidence
            && !result.isUnconfiguredCamera
            && !result.isEmptyCard
            && !result.isPhotoOnly
            && !result.isUnformattedCard
            && !alreadyInHistory {
            
            performRename()
        }
    }
    
    private func performRename() {
        guard let vol = volume else { return }
        isRenaming = true
        let oldName = vol.name
        let newName = previewNewName
        
        RenamerEngine.renameVolume(at: vol.path, bsdNode: vol.bsdNode, fileSystem: vol.fileSystem, to: newName) { success, msg in
            isRenaming = false
            if success {
                saveHistoryItem(oldName: oldName, newName: newName)
            }
            activeAlert = .resultNotice(message: msg)
        }
    }
    
    private func saveHistoryItem(oldName: String, newName: String) {
        guard let vol = volume else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        
        let item = RenameHistoryItem(
            id: UUID(),
            originalName: oldName,
            newName: newName,
            firstClipName: scanResult?.firstClipName,
            lastClipName: scanResult?.lastClipName,
            clipCount: scanResult?.clipCount ?? 0,
            totalFileCount: scanResult?.totalFileCount ?? 0,
            usedSpace: vol.usedGBFormatted,
            deviceType: scanResult?.deviceType ?? "Generic",
            timestamp: Date(),
            dateDayString: todayStr,
            isUnformatted: scanResult?.isUnformattedCard ?? false,
            isEmptyCard: scanResult?.isEmptyCard ?? false
        )
        
        RenameHistoryStore.shared.add(item)
        if let encoded = try? JSONEncoder().encode(RenameHistoryStore.shared.items) {
            historyData = encoded
        }
    }
}

struct HDEInfoCardView: View {
    @ObservedObject var langManager = LanguageManager.shared
    let hde: HDEResult
    let usedGBFormatted: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundColor(.purple)
                Text(langManager.text("Codex HDE 无损压缩容量推演", "Codex HDE Storage Calculation"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                Spacer()
                if hde.isCLIAvailable {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                        Text(langManager.text("Codex HDE CLI 命令行加持", "Codex HDE CLI Engine"))
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
                } else {
                    Text(langManager.text("Codex HDE 官方模型推演", "Codex HDE Lossless Model"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.purple.opacity(0.8))
                }
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(langManager.text("当前素材已用空间", "Used Space"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(usedGBFormatted)
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
                "检测到摄影机未设置机位号 (默认 C0001 格式)，已拦截自动重命名。请在摄影机内补全机位，或在右侧面板手动确认。",
                "Unconfigured Camera ID detected (Default C0001). Auto-rename blocked. Please set Camera ID in camera or confirm manually in right panel."
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

struct PhotoCardBannerView: View {
    @ObservedObject var langManager = LanguageManager.shared
    let photoCount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .foregroundColor(.purple)
            let msg = langManager.text(
                "检测到平面照片卡 (含 \(photoCount) 张照片，无视频)，已自动保护。",
                "Photo-only volume detected (Contains \(photoCount) photos, no video). Auto-rename bypassed."
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

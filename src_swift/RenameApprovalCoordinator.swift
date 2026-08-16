import Foundation
import Combine

@MainActor
final class RenameApprovalCoordinator: ObservableObject {
    static let shared = RenameApprovalCoordinator()

    @Published private(set) var pendingCandidates: [RenameCandidate] = []
    @Published private(set) var lastResult: RenameExecutionResult?
    @Published private(set) var isScanning = false

    private let store = RenameApprovalStore.shared
    private var scanTasks: [String: Task<Void, Never>] = [:]
    private var scanGenerations: [String: UUID] = [:]
    private var scannedVolumeKeys = Set<String>()
    private var excludedMountPaths = Set<String>()
    private var mountedNamesByBSDNode: [String: String] = [:]
    private var externalScanIDs = Set<UUID>()
    private let automaticRenameQueue = AutomaticRenameQueue()

    private init() {
        pendingCandidates = store.candidates
    }

    var pendingCount: Int { pendingCandidates.filter { $0.state == .pending || $0.state == .failed }.count }
    var batchCandidates: [RenameCandidate] {
        guard RenameOperationPolicy.allowsExecution(via: .batchApproval, isScanning: isScanning) else { return [] }
        return pendingCandidates.filter { isSafeForAutomaticApproval($0) }
    }

    func refresh(volumes: [MountedVolume]) {
        isScanning = true
        let eligible = volumes.filter {
            $0.isRemovable && !$0.isInternal && $0.canAttemptManualRename
        }
        mountedNamesByBSDNode = Dictionary(uniqueKeysWithValues: eligible.map {
            ($0.bsdNode, Self.normalizeVolumeName($0.name))
        })
        let mountedSessionIDs = Set(eligible.compactMap(\.mountSessionID))
        let activeVolumeIDs = Set(eligible.map(\.id))
        for id in Array(scanTasks.keys) where !activeVolumeIDs.contains(id) {
            scanTasks[id]?.cancel()
            scanTasks[id] = nil
            scanGenerations[id] = nil
        }
        store.markStale(excludingMountedSessionIDs: mountedSessionIDs)
        scannedVolumeKeys = scannedVolumeKeys.filter { key in
            activeVolumeIDs.contains { key.hasPrefix("\($0)|") }
        }
        syncFromStore()
        for volume in eligible where scanTasks[volume.id] == nil {
            let id = volume.id
            let scanKey = "\(volume.id)|\(volume.name)|\(volume.path)|\(volume.fileSystem)"
            guard !scannedVolumeKeys.contains(scanKey) else { continue }
            scannedVolumeKeys.insert(scanKey)
            let generation = UUID()
            scanGenerations[id] = generation
            scanTasks[id] = Task.detached(priority: .userInitiated) { [weak self] in
                let scan = MediaScanner.scan(volumePath: volume.path)
                guard !Task.isCancelled else { return }
                await self?.accept(scan: scan, volume: volume, generation: generation)
            }
        }
        updateScanningState()
        if !isScanning { enqueueAllSafeAutomaticCandidates() }
    }

    func rescan(volumes: [MountedVolume]) {
        for task in scanTasks.values { task.cancel() }
        scanTasks.removeAll()
        scanGenerations.removeAll()
        scannedVolumeKeys.removeAll()
        refresh(volumes: volumes)
    }

    func setExcludedMountPaths(_ paths: Set<String>) {
        excludedMountPaths = paths
        for candidate in pendingCandidates where paths.contains(candidate.mountPath) {
            store.remove(id: candidate.id)
        }
        scannedVolumeKeys = scannedVolumeKeys.filter { key in
            !paths.contains { key.contains("|\($0)|") }
        }
        syncFromStore()
    }

    func beginExternalScan() -> UUID {
        let id = UUID()
        externalScanIDs.insert(id)
        updateScanningState()
        return id
    }

    func endExternalScan(_ id: UUID) {
        externalScanIDs.remove(id)
        updateScanningState()
        if !isScanning { enqueueAllSafeAutomaticCandidates() }
    }

    func ingest(volume: MountedVolume, scan: ScanResult, requestedName: String? = nil) -> RenameCandidate? {
        guard scan.isScanComplete, volume.canAttemptManualRename else { return nil }
        guard !scan.isEmptyCard, !scan.isPhotoOnly, !scan.isUnformattedCard else { return nil }
        let candidate = RenameCandidate(volume: volume, scan: scan, requestedName: requestedName)
        store.upsert(candidate)
        syncFromStore()
        return pendingCandidates.first(where: { $0.hasSameMountedIdentity(as: candidate) })
    }

    func approveSuggestedName(candidateID: UUID) async -> RenameExecutionResult {
        guard RenameOperationPolicy.allowsExecution(via: .suggestedApproval, isScanning: isScanning) else {
            return finish(candidateID: candidateID, success: false, message: "仍有存储卡正在扫描。请等待全部已插入卡片完成扫描后再批准。", actualName: nil)
        }
        guard let candidate = pendingCandidates.first(where: { $0.id == candidateID }) else {
            return finish(candidateID: candidateID, success: false, message: "待审核记录不存在。", actualName: nil)
        }
        guard candidate.state != .stale else {
            return finish(candidateID: candidateID, success: false, message: "存储卡已卸载或挂载会话已变化，请重新插卡并扫描。", actualName: nil)
        }
        guard let name = candidate.effectiveName else {
            return finish(candidateID: candidateID, success: false, message: "没有可批准的建议卷名。", actualName: nil)
        }
        guard !hasTargetNameConflict(for: candidate) else {
            return finish(
                candidateID: candidateID,
                success: false,
                message: "检测到另一张已挂载卡也将使用卷名 \(name.uppercased())。为避免 Silverstack 再次出现同名卡，请先手动为其中一张指派不同卷号。",
                actualName: nil
            )
        }
        return await execute(candidate: candidate, requestedName: name)
    }

    func assignVolumeName(candidateID: UUID, request: VolumeNameRequest) async -> RenameExecutionResult {
        guard RenameOperationPolicy.allowsExecution(via: .manualAssignment, isScanning: isScanning) else {
            return finish(candidateID: candidateID, success: false, message: "仍有存储卡正在扫描。请等待全部已插入卡片完成扫描后再执行重命名。", actualName: nil)
        }
        guard let candidate = pendingCandidates.first(where: { $0.id == candidateID }) else {
            return finish(candidateID: candidateID, success: false, message: "待审核记录不存在。", actualName: nil)
        }
        guard candidate.state != .stale else {
            return finish(candidateID: candidateID, success: false, message: "存储卡已卸载或挂载会话已变化，请重新插卡并扫描。", actualName: nil)
        }
        do {
            let name = try VolumeNameBuilder.build(request, fileSystem: candidate.fileSystem)
            var updated = candidate
            updated.requestedName = name
            store.update(updated)
            syncFromStore()
            guard !hasTargetNameConflict(for: updated) else {
                return finish(
                    candidateID: candidateID,
                    success: false,
                    message: "卷名 \(name) 已被另一张已挂载卡占用。请为其中一张卡指派不同卷号后再执行。",
                    actualName: nil
                )
            }
            return await execute(
                candidate: updated,
                requestedName: name,
                reuseCount: request.recordedReuseCount,
                duplicateIndex: request.duplicateIndex
            )
        } catch {
            return finish(candidateID: candidateID, success: false, message: error.localizedDescription, actualName: nil)
        }
    }

    func approveBatch() async -> [RenameExecutionResult] {
        guard RenameOperationPolicy.allowsExecution(via: .batchApproval, isScanning: isScanning) else {
            return [finish(candidateID: UUID(), success: false, message: "仍有存储卡正在扫描，批量批准已暂停。", actualName: nil)]
        }
        var results: [RenameExecutionResult] = []
        for candidate in batchCandidates {
            let result = await approveSuggestedName(candidateID: candidate.id)
            results.append(result)
            if !result.success { break }
        }
        return results
    }

    func dismiss(candidateID: UUID) {
        store.remove(id: candidateID)
        syncFromStore()
        enqueueAllSafeAutomaticCandidates()
    }

    @discardableResult
    func enqueueAutomaticApproval(candidateID: UUID) -> Bool {
        guard RenameOperationPolicy.allowsExecution(via: .automatic, isScanning: isScanning) else { return false }
        guard let candidate = pendingCandidates.first(where: { $0.id == candidateID }),
              isSafeForAutomaticApproval(candidate) else { return false }
        automaticRenameQueue.enqueue(candidate.id) { [weak self] queuedCandidateID in
            guard let self else { return }
            while self.isScanning || MediaOperationCoordinator.shared.isBusy {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            guard UserDefaults.standard.bool(forKey: "menuBarAutoRenameEnabled"),
                  let current = self.pendingCandidates.first(where: { $0.id == queuedCandidateID }) else { return }
            guard self.isSafeForAutomaticApproval(current) else {
                if self.hasTargetNameConflict(for: current) {
                    _ = self.finish(
                        candidateID: queuedCandidateID,
                        success: false,
                        message: "自动重命名已暂停：卷名 \(current.effectiveName ?? "—") 已被另一张卡占用。请在手动工作区勾选“机位号重复”，使用 _1、_2 等冲突编号。",
                        actualName: nil
                    )
                }
                return
            }
            _ = await self.approveSuggestedName(candidateID: queuedCandidateID)
        }
        return true
    }

    func hasTargetNameConflict(for candidate: RenameCandidate) -> Bool {
        candidate.hasConflictingTargetName(
            among: pendingCandidates,
            occupiedNames: occupiedMountedNames(excludingBSDNode: candidate.bsdNode)
        )
    }

    func isSafeForAutomaticApproval(_ candidate: RenameCandidate) -> Bool {
        RenameOperationPolicy.allowsExecution(via: .automatic, isScanning: isScanning)
            && candidate.isSafeForAutomaticApproval(
            among: pendingCandidates,
            occupiedNames: occupiedMountedNames(excludingBSDNode: candidate.bsdNode)
        )
    }

    func nextAvailableDuplicateIndex(
        for request: VolumeNameRequest,
        fileSystem: String,
        excludingCandidateID: UUID? = nil,
        excludingBSDNode: String? = nil
    ) -> Int? {
        let candidateBSDNode = excludingBSDNode ?? excludingCandidateID.flatMap { id in
            pendingCandidates.first(where: { $0.id == id })?.bsdNode
        }
        let otherCandidates = pendingCandidates.filter {
            $0.id != excludingCandidateID
                && $0.bsdNode != candidateBSDNode
                && $0.state != .stale
        }
        let occupied = occupiedMountedNames(excludingBSDNode: candidateBSDNode)
        for index in 1...999 {
            var proposed = request
            proposed.duplicateIndex = index
            guard let name = try? VolumeNameBuilder.build(proposed, fileSystem: fileSystem) else { continue }
            let normalized = Self.normalizeVolumeName(name)
            let pendingConflict = otherCandidates.contains { $0.normalizedEffectiveName == normalized }
            if !pendingConflict && !occupied.contains(normalized) { return index }
        }
        return nil
    }

    func rescan(candidateID: UUID) {
        guard let candidate = pendingCandidates.first(where: { $0.id == candidateID }) else { return }
        let volume = MountedVolume(
            name: candidate.originalName,
            originalName: candidate.originalName,
            path: candidate.mountPath,
            bsdNode: candidate.bsdNode,
            volumeUUID: candidate.volumeUUID,
            mediaUUID: candidate.mediaUUID,
            mountSessionID: candidate.mountSessionID,
            isRemovable: true,
            isInternal: false,
            freeBytes: 0,
            totalBytes: 0,
            isGenericName: true,
            fileSystem: candidate.fileSystem
        )
        scannedVolumeKeys = scannedVolumeKeys.filter { !$0.hasPrefix("\(volume.id)|") }
        scanTasks[volume.id]?.cancel()
        let generation = UUID()
        scanGenerations[volume.id] = generation
        isScanning = true
        scanTasks[volume.id] = Task.detached(priority: .userInitiated) { [weak self] in
            let scan = MediaScanner.scan(volumePath: volume.path)
            guard !Task.isCancelled else { return }
            await self?.accept(scan: scan, volume: volume, generation: generation)
        }
    }

    private func accept(scan: ScanResult, volume: MountedVolume, generation: UUID) async {
        guard scanGenerations[volume.id] == generation else { return }
        scanTasks[volume.id] = nil
        scanGenerations[volume.id] = nil
        updateScanningState()
        guard !excludedMountPaths.contains(volume.path) else {
            return
        }
        if scan.isScanComplete, let candidate = ingest(volume: volume, scan: scan) {
            _ = candidate
        }
        if !isScanning { enqueueAllSafeAutomaticCandidates() }
    }

    private func execute(
        candidate: RenameCandidate,
        requestedName: String,
        reuseCount: Int? = nil,
        duplicateIndex: Int? = nil
    ) async -> RenameExecutionResult {
        guard !MediaOperationCoordinator.shared.isBusy else {
            return finish(candidateID: candidate.id, success: false, message: "当前已有存储卡操作正在执行。", actualName: nil)
        }
        if candidate.mediaUUID == nil {
            let currentFingerprint = MediaScanner.mediaFingerprint(volumePath: candidate.mountPath)
            guard currentFingerprint.firstClipName == candidate.firstClipName,
                  currentFingerprint.lastClipName == candidate.lastClipName else {
                return finish(
                    candidateID: candidate.id,
                    success: false,
                    message: "重命名已取消：当前卡片的首末素材与扫描记录不一致，可能已换卡，请重新扫描。",
                    actualName: nil
                )
            }
        }

        var approving = candidate
        approving.state = .approving
        store.update(approving)
        syncFromStore()
        MediaOperationCoordinator.shared.beginOperation()
        let result = await RenamerEngine.renameVolumeAsync(
            at: candidate.mountPath,
            bsdNode: candidate.bsdNode,
            volumeUUID: candidate.volumeUUID.isEmpty ? nil : candidate.volumeUUID,
            mediaUUID: candidate.mediaUUID,
            fileSystem: candidate.fileSystem,
            to: requestedName
        )
        MediaOperationCoordinator.shared.endOperation()

        guard result.success, let actualName = result.actualName else {
            var failed = candidate
            failed.state = .failed
            failed.lastError = result.message
            store.update(failed)
            syncFromStore()
            return finish(candidateID: candidate.id, success: false, message: result.message, actualName: result.actualName)
        }

        let history = RenameHistoryItem(
            originalName: candidate.originalName,
            newName: actualName,
            firstClipName: candidate.firstClipName,
            lastClipName: candidate.lastClipName,
            clipCount: candidate.clipCount,
            totalFileCount: candidate.totalFileCount,
            usedSpace: candidate.usedSpace,
            deviceType: candidate.deviceType,
            timestamp: Date(),
            dateDayString: Self.dayString(for: Date()),
            isUnformatted: candidate.isUnformatted,
            isEmptyCard: candidate.isEmptyCard,
            requestedName: requestedName,
            reuseCount: reuseCount,
            duplicateIndex: duplicateIndex,
            volumeUUID: candidate.volumeUUID.isEmpty ? nil : candidate.volumeUUID,
            mediaUUID: candidate.mediaUUID,
            bsdNode: candidate.bsdNode,
            mountedPath: candidate.mountPath,
            fileSystem: candidate.fileSystem,
            isHighConfidence: candidate.isHighConfidence,
            isPhotoOnly: candidate.isPhotoOnly,
            isUnconfiguredCamera: candidate.isUnconfiguredCamera,
            cameraMetadataEvidence: candidate.cameraMetadataEvidence
        )
        guard RenameHistoryStore.shared.add(history) else {
            var failed = candidate
            failed.state = .failed
            failed.lastError = "卷已重命名，但审计记录保存失败。"
            store.update(failed)
            syncFromStore()
            return finish(candidateID: candidate.id, success: false, message: failed.lastError!, actualName: actualName)
        }
        mountedNamesByBSDNode[candidate.bsdNode] = Self.normalizeVolumeName(actualName)
        store.remove(id: candidate.id)
        syncFromStore()
        return finish(candidateID: candidate.id, success: true, message: result.message, actualName: actualName)
    }

    private func finish(candidateID: UUID, success: Bool, message: String, actualName: String?) -> RenameExecutionResult {
        let result = RenameExecutionResult(candidateID: candidateID, success: success, message: message, actualName: actualName)
        lastResult = result
        return result
    }

    private func syncFromStore() { pendingCandidates = store.candidates }

    private func updateScanningState() {
        isScanning = !scanTasks.isEmpty || !externalScanIDs.isEmpty
    }

    private func enqueueAllSafeAutomaticCandidates() {
        guard !isScanning,
              UserDefaults.standard.bool(forKey: "menuBarAutoRenameEnabled") else { return }
        for candidate in pendingCandidates where isSafeForAutomaticApproval(candidate) {
            enqueueAutomaticApproval(candidateID: candidate.id)
        }
    }

    private func occupiedMountedNames(excludingBSDNode: String?) -> Set<String> {
        Set(mountedNamesByBSDNode.compactMap { bsdNode, name in
            bsdNode == excludingBSDNode ? nil : name
        })
    }

    private static func normalizeVolumeName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .uppercased()
    }

    private static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

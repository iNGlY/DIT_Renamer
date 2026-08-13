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
    private let automaticRenameQueue = AutomaticRenameQueue()

    private init() {
        pendingCandidates = store.candidates
    }

    var pendingCount: Int { pendingCandidates.filter { $0.state == .pending || $0.state == .failed }.count }
    var batchCandidates: [RenameCandidate] {
        pendingCandidates.filter { $0.isSafeForAutomaticApproval(among: pendingCandidates) }
    }

    func refresh(volumes: [MountedVolume]) {
        isScanning = true
        let eligible = volumes.filter { $0.isRemovable && !$0.isInternal && $0.volumeUUID != nil }
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
        isScanning = !scanTasks.isEmpty
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

    func ingest(volume: MountedVolume, scan: ScanResult, requestedName: String? = nil) -> RenameCandidate? {
        guard scan.isScanComplete, volume.volumeUUID != nil else { return nil }
        guard !scan.isEmptyCard, !scan.isPhotoOnly, !scan.isUnformattedCard else { return nil }
        guard !volume.isUniqueCameraName || requestedName != nil else { return nil }
        let candidate = RenameCandidate(volume: volume, scan: scan, requestedName: requestedName)
        guard candidate.effectiveName != nil || !volume.isUniqueCameraName else { return nil }
        store.upsert(candidate)
        syncFromStore()
        return pendingCandidates.first(where: { $0.hasSameMountedIdentity(as: candidate) })
    }

    func approveSuggestedName(candidateID: UUID) async -> RenameExecutionResult {
        guard let candidate = pendingCandidates.first(where: { $0.id == candidateID }) else {
            return finish(candidateID: candidateID, success: false, message: "待审核记录不存在。", actualName: nil)
        }
        guard candidate.state != .stale else {
            return finish(candidateID: candidateID, success: false, message: "存储卡已卸载或挂载会话已变化，请重新插卡并扫描。", actualName: nil)
        }
        guard let name = candidate.effectiveName else {
            return finish(candidateID: candidateID, success: false, message: "没有可批准的建议卷名。", actualName: nil)
        }
        return await execute(candidate: candidate, requestedName: name)
    }

    func assignVolumeName(candidateID: UUID, request: VolumeNameRequest) async -> RenameExecutionResult {
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
            return await execute(candidate: updated, requestedName: name)
        } catch {
            return finish(candidateID: candidateID, success: false, message: error.localizedDescription, actualName: nil)
        }
    }

    func approveBatch() async -> [RenameExecutionResult] {
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
        guard !excludedMountPaths.contains(volume.path) else {
            isScanning = !scanTasks.isEmpty
            return
        }
        if scan.isScanComplete, let candidate = ingest(volume: volume, scan: scan) {
            let automatic = UserDefaults.standard.bool(forKey: "menuBarAutoRenameEnabled")
            if automatic
                && volume.isGenericName
                && candidate.isSafeForAutomaticApproval(among: pendingCandidates) {
                automaticRenameQueue.enqueue(candidate.id) { [weak self] candidateID in
                    guard let self else { return }
                    while self.isScanning || MediaOperationCoordinator.shared.isBusy {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                    guard UserDefaults.standard.bool(forKey: "menuBarAutoRenameEnabled"),
                          let current = self.pendingCandidates.first(where: { $0.id == candidateID }),
                          current.isSafeForAutomaticApproval(among: self.pendingCandidates) else { return }
                    _ = await self.approveSuggestedName(candidateID: candidateID)
                }
            }
        }
        isScanning = !scanTasks.isEmpty
    }

    private func execute(candidate: RenameCandidate, requestedName: String) async -> RenameExecutionResult {
        guard !MediaOperationCoordinator.shared.isBusy else {
            return finish(candidateID: candidate.id, success: false, message: "当前已有存储卡操作正在执行。", actualName: nil)
        }
        guard !candidate.volumeUUID.isEmpty else {
            return finish(candidateID: candidate.id, success: false, message: "未能确认卡片 UUID，已取消重命名。", actualName: nil)
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
            volumeUUID: candidate.volumeUUID,
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
            volumeUUID: candidate.volumeUUID,
            mediaUUID: candidate.mediaUUID,
            bsdNode: candidate.bsdNode,
            mountedPath: candidate.mountPath
        )
        guard RenameHistoryStore.shared.add(history) else {
            var failed = candidate
            failed.state = .failed
            failed.lastError = "卷已重命名，但审计记录保存失败。"
            store.update(failed)
            syncFromStore()
            return finish(candidateID: candidate.id, success: false, message: failed.lastError!, actualName: actualName)
        }
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

    private static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

import Foundation

@MainActor
final class MediaOperationCoordinator {
    static let shared = MediaOperationCoordinator()
    var isBusy = false
    func beginOperation() { isBusy = true }
    func endOperation() { isBusy = false }
}

enum MediaScanner {
    static func scan(volumePath: String) -> ScanResult {
        fatalError("Scanning must not begin in the scan-lock gate test")
    }

    static func mediaFingerprint(volumePath: String) -> (firstClipName: String?, lastClipName: String?) {
        fatalError("Media fingerprinting must not begin in the scan-lock gate test")
    }
}

enum RenamerEngine {
    static func renameVolumeAsync(
        at path: String,
        bsdNode: String,
        volumeUUID: String?,
        mediaUUID: String?,
        fileSystem: String,
        to requestedName: String
    ) async -> (success: Bool, message: String, actualName: String?) {
        fatalError("The disk rename engine must not run while scanning")
    }
}

@MainActor
final class RenameHistoryStore {
    static let shared = RenameHistoryStore()
    func add(_ item: RenameHistoryItem) -> Bool {
        fatalError("Audit history must not change while scanning")
    }
}

@main
@MainActor
struct RenameApprovalCoordinatorGateTests {
    static func main() async {
        UserDefaults.standard.set(false, forKey: "menuBarAutoRenameEnabled")
        let coordinator = RenameApprovalCoordinator.shared
        let scanID = coordinator.beginExternalScan()
        let candidateID = UUID()

        precondition(!coordinator.enqueueAutomaticApproval(candidateID: candidateID))

        let suggested = await coordinator.approveSuggestedName(candidateID: candidateID)
        precondition(!suggested.success && suggested.message.contains("扫描"))

        let batch = await coordinator.approveBatch()
        precondition(batch.count == 1 && !batch[0].success && batch[0].message.contains("扫描"))

        let manual = await coordinator.assignVolumeName(
            candidateID: candidateID,
            request: VolumeNameRequest(
                cameraLetter: "A",
                rollNumber: "001",
                reuseCount: nil,
                includeReuseCount: false,
                duplicateIndex: nil,
                suffix: nil,
                includeSuffix: false
            )
        )
        precondition(!manual.success && manual.message.contains("扫描"))

        coordinator.endExternalScan(scanID)
        print("RenameApprovalCoordinatorGateTests: PASS")
    }
}

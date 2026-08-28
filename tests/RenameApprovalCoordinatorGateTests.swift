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
        let defaults = UserDefaults.standard
        let originalAutomaticRenameSetting = defaults.object(forKey: "menuBarAutoRenameEnabled")
        defer {
            if let originalAutomaticRenameSetting {
                defaults.set(originalAutomaticRenameSetting, forKey: "menuBarAutoRenameEnabled")
            } else {
                defaults.removeObject(forKey: "menuBarAutoRenameEnabled")
            }
        }
        defaults.set(false, forKey: "menuBarAutoRenameEnabled")
        let coordinator = RenameApprovalCoordinator.shared
        for candidate in coordinator.pendingCandidates where [
            "UUIDLESS-STANDARD-MANUAL-TEST",
            "ALREADY-RENAMED-SESSION",
            "AUTO-RESERVATION-SESSION"
        ].contains(candidate.mountSessionID ?? "") {
            coordinator.dismiss(candidateID: candidate.id)
        }
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

        let standardUUIDLessVolume = MountedVolume(
            name: "A001",
            originalName: "A001",
            path: "/Volumes/A001 UUIDless Manual Test",
            bsdNode: "disk99s1",
            volumeUUID: nil,
            mediaUUID: nil,
            mountSessionID: "UUIDLESS-STANDARD-MANUAL-TEST",
            isRemovable: true,
            isInternal: false,
            freeBytes: 1,
            totalBytes: 2,
            isGenericName: false,
            fileSystem: "EXFAT",
            accessLevel: .inspectionOnly,
            isReadOnly: false
        )
        let standardScan = ScanResult(
            suggestedName: nil,
            cameraLetter: nil,
            rollNumber: nil,
            suffix: nil,
            deviceType: "Sony FX3",
            clipCount: 2,
            totalFileCount: 4,
            firstClipName: "C0001.MP4",
            lastClipName: "C0002.MP4",
            isHighConfidence: true
        )
        let standardCandidate = coordinator.ingest(
            volume: standardUUIDLessVolume,
            scan: standardScan
        )
        precondition(
            standardCandidate != nil,
            "A writable UUID-less card with a standard volume name must remain available for manual assignment"
        )
        precondition(
            standardCandidate?.effectiveName == nil,
            "A standard volume without a safe suggestion must wait for explicit manual assignment"
        )
        precondition(
            standardCandidate?.canBeBatchApproved == false,
            "A UUID-less standard volume must never enter batch approval"
        )
        if let standardCandidate {
            coordinator.dismiss(candidateID: standardCandidate.id)
        }

        let alreadyRenamedVolume = MountedVolume(
            name: "A001",
            originalName: "A001",
            path: "/Volumes/A001 Already Renamed Test",
            bsdNode: "disk98s1",
            volumeUUID: "ALREADY-RENAMED-UUID",
            mediaUUID: "ALREADY-RENAMED-MEDIA",
            mountSessionID: "ALREADY-RENAMED-SESSION",
            isRemovable: true,
            isInternal: false,
            freeBytes: 1,
            totalBytes: 2,
            isGenericName: false,
            fileSystem: "EXFAT",
            accessLevel: .renameCapable,
            isReadOnly: false
        )
        let alreadyRenamedScan = ScanResult(
            suggestedName: "A001",
            cameraLetter: "A",
            rollNumber: "001",
            suffix: nil,
            deviceType: "Sony FX3",
            clipCount: 2,
            totalFileCount: 4,
            firstClipName: "A001C001.MP4",
            lastClipName: "A001C002.MP4",
            isHighConfidence: true
        )
        let alreadyRenamedCandidate = coordinator.ingest(
            volume: alreadyRenamedVolume,
            scan: alreadyRenamedScan
        )
        if let alreadyRenamedCandidate {
            coordinator.dismiss(candidateID: alreadyRenamedCandidate.id)
        }
        precondition(
            alreadyRenamedCandidate == nil,
            "A card that already has its approved target name must not re-enter the review queue after automatic remount"
        )

        defaults.set(true, forKey: "menuBarAutoRenameEnabled")
        let reservationScanID = coordinator.beginExternalScan()
        let autoVolume = MountedVolume(
            name: "Untitled",
            originalName: "Untitled",
            path: "/Volumes/Auto Reservation Test",
            bsdNode: "disk97s1",
            volumeUUID: "AUTO-RESERVATION-UUID",
            mediaUUID: "AUTO-RESERVATION-MEDIA",
            mountSessionID: "AUTO-RESERVATION-SESSION",
            isRemovable: true,
            isInternal: false,
            freeBytes: 1,
            totalBytes: 2,
            isGenericName: true,
            fileSystem: "EXFAT",
            accessLevel: .renameCapable,
            isReadOnly: false
        )
        let automaticReservationScan = ScanResult(
            suggestedName: "Z997",
            cameraLetter: "Z",
            rollNumber: "997",
            suffix: nil,
            deviceType: "Sony FX3",
            clipCount: 2,
            totalFileCount: 4,
            firstClipName: "Z997C001.MP4",
            lastClipName: "Z997C002.MP4",
            isHighConfidence: true
        )
        let autoCandidate = coordinator.ingest(volume: autoVolume, scan: automaticReservationScan)
        precondition(autoCandidate != nil, "The automatic test card should enter the internal operation queue")
        precondition(
            !coordinator.reviewCandidates.contains { $0.id == autoCandidate?.id },
            "An automatic candidate must be reserved before publication and never flash in the human review queue while sibling scans continue"
        )
        if let autoCandidate {
            coordinator.dismiss(candidateID: autoCandidate.id)
        }
        defaults.set(false, forKey: "menuBarAutoRenameEnabled")
        coordinator.endExternalScan(reservationScanID)
        print("RenameApprovalCoordinatorGateTests: PASS")
    }
}

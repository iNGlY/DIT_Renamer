import Foundation

@main
struct RenameApprovalModelsTests {
    static func main() throws {
        let withSuffix = VolumeNameRequest(
            cameraLetter: "a",
            rollNumber: "003",
            reuseCount: 2,
            suffix: "_S",
            includeSuffix: true
        )
        let withoutSuffix = VolumeNameRequest(
            cameraLetter: "A",
            rollNumber: "003",
            reuseCount: 2,
            suffix: "_S",
            includeSuffix: false
        )

        let suffixName = try VolumeNameBuilder.build(withSuffix)
        let plainName = try VolumeNameBuilder.build(withoutSuffix)
        precondition(suffixName == "A003-2_S")
        precondition(plainName == "A003-2")

        do {
            _ = try VolumeNameBuilder.build(
                VolumeNameRequest(
                    cameraLetter: "AB",
                    rollNumber: "001",
                    reuseCount: 0,
                    suffix: nil,
                    includeSuffix: false
                )
            )
            preconditionFailure("Invalid camera letter was accepted")
        } catch VolumeNameError.invalidCameraLetter {
            // Expected.
        }

        do {
            _ = try VolumeNameBuilder.build(
                VolumeNameRequest(
                    cameraLetter: "A",
                    rollNumber: "1234567890",
                    reuseCount: 0,
                    suffix: "_S",
                    includeSuffix: true
                ),
                fileSystem: "exFAT"
            )
            preconditionFailure("An exFAT name longer than 11 characters was accepted")
        } catch VolumeNameError.tooLong {
            // Expected.
        }

        let duplicateUUIDA = MountedVolume(
            name: "Untitled", originalName: "Untitled", path: "/Volumes/Untitled",
            bsdNode: "disk4s1", volumeUUID: "DUPLICATE", mediaUUID: "MEDIA-A",
            isRemovable: true, isInternal: false, freeBytes: 1, totalBytes: 2,
            isGenericName: true, fileSystem: "EXFAT"
        )
        let duplicateUUIDB = MountedVolume(
            name: "Untitled 1", originalName: "Untitled", path: "/Volumes/Untitled 1",
            bsdNode: "disk5s1", volumeUUID: "DUPLICATE", mediaUUID: "MEDIA-B",
            isRemovable: true, isInternal: false, freeBytes: 1, totalBytes: 2,
            isGenericName: true, fileSystem: "EXFAT"
        )
        precondition(duplicateUUIDA.id != duplicateUUIDB.id, "Duplicate UUID cards must remain distinct while mounted")

        let scanA = ScanResult(
            suggestedName: "A247", cameraLetter: "A", rollNumber: "247", suffix: nil,
            deviceType: "Sony FX3", clipCount: 2, totalFileCount: 4,
            firstClipName: "A247C001.MP4", lastClipName: "A247C002.MP4",
            isHighConfidence: true
        )
        let scanB = ScanResult(
            suggestedName: "B101", cameraLetter: "B", rollNumber: "101", suffix: nil,
            deviceType: "Sony FX6", clipCount: 2, totalFileCount: 4,
            firstClipName: "B101C001.MXF", lastClipName: "B101C002.MXF",
            isHighConfidence: true
        )
        let candidateA = RenameCandidate(volume: duplicateUUIDA, scan: scanA)
        let candidateB = RenameCandidate(volume: duplicateUUIDB, scan: scanB)
        precondition(!candidateA.hasSameMediaIdentity(as: candidateB), "Different clips must keep duplicate-UUID cards as separate approvals")
        precondition(!candidateA.hasSameMountedIdentity(as: candidateB), "Different readers must keep mounted cards operationally distinct")
        precondition(candidateA.canBeBatchApproved && candidateB.canBeBatchApproved, "Both high-confidence duplicate-UUID cards must remain batch eligible")
        precondition(candidateA.isSafeForAutomaticApproval(among: [candidateA, candidateB]))
        precondition(candidateB.isSafeForAutomaticApproval(among: [candidateA, candidateB]))

        let clonedScan = ScanResult(
            suggestedName: "A247", cameraLetter: "A", rollNumber: "247", suffix: nil,
            deviceType: "Sony FX3", clipCount: 2, totalFileCount: 4,
            firstClipName: "A247C001.MP4", lastClipName: "A247C002.MP4",
            isHighConfidence: true
        )
        let clonedCandidateA = RenameCandidate(volume: duplicateUUIDA, scan: clonedScan)
        let clonedCandidateB = RenameCandidate(volume: duplicateUUIDB, scan: clonedScan)
        precondition(clonedCandidateA.hasSameMediaIdentity(as: clonedCandidateB), "Cloned media should retain the same content identity")
        precondition(!clonedCandidateA.hasSameMountedIdentity(as: clonedCandidateB), "Cloned cards in two readers must not overwrite each other in the live queue")
        precondition(!clonedCandidateA.isSafeForAutomaticApproval(among: [clonedCandidateA, clonedCandidateB]), "Exact duplicate identities must require manual review")
        precondition(!clonedCandidateB.isSafeForAutomaticApproval(among: [clonedCandidateA, clonedCandidateB]), "Exact duplicate identities must require manual review")

        print("RenameApprovalModelsTests: PASS")
    }
}

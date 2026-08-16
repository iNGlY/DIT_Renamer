import Foundation

@main
struct RenameApprovalModelsTests {
    static func main() throws {
        for path in RenameExecutionPath.allCases {
            precondition(
                !RenameOperationPolicy.allowsExecution(via: path, isScanning: true),
                "Every rename entry path must remain blocked while any card scan is active"
            )
            precondition(
                RenameOperationPolicy.allowsExecution(via: path, isScanning: false),
                "Rename entry paths should reopen after all scans finish"
            )
        }

        let withSuffix = VolumeNameRequest(
            cameraLetter: "a",
            rollNumber: "003",
            reuseCount: 2,
            includeReuseCount: true,
            duplicateIndex: nil,
            suffix: "_S",
            includeSuffix: true
        )
        let withoutSuffix = VolumeNameRequest(
            cameraLetter: "A",
            rollNumber: "003",
            reuseCount: nil,
            includeReuseCount: false,
            duplicateIndex: nil,
            suffix: "_S",
            includeSuffix: false
        )
        let withDifferentReuseCount = VolumeNameRequest(
            cameraLetter: "A",
            rollNumber: "003",
            reuseCount: 99,
            includeReuseCount: true,
            duplicateIndex: nil,
            suffix: "_S",
            includeSuffix: true
        )

        let suffixName = try VolumeNameBuilder.build(withSuffix)
        let differentReuseCountName = try VolumeNameBuilder.build(withDifferentReuseCount)
        let plainName = try VolumeNameBuilder.build(withoutSuffix)
        precondition(suffixName == "A003_S", "Reuse metadata must never change the actual volume name")
        precondition(
            differentReuseCountName == suffixName,
            "Changing only the reuse count must not change the actual volume name"
        )
        precondition(plainName == "A003")

        do {
            _ = try VolumeNameBuilder.build(
                VolumeNameRequest(
                    cameraLetter: "A",
                    rollNumber: "003",
                    reuseCount: nil,
                    includeReuseCount: true,
                    duplicateIndex: nil,
                    suffix: nil,
                    includeSuffix: false
                )
            )
            preconditionFailure("Enabled reuse recording accepted an empty value")
        } catch VolumeNameError.missingReuseCount {
            // Expected.
        }

        let duplicateCameraName = try VolumeNameBuilder.build(
            VolumeNameRequest(
                cameraLetter: "A",
                rollNumber: "001",
                reuseCount: nil,
                includeReuseCount: false,
                duplicateIndex: 1,
                suffix: nil,
                includeSuffix: false
            ),
            fileSystem: "exFAT"
        )
        precondition(duplicateCameraName == "A001_1", "Duplicate camera IDs must use an explicit _1 conflict marker")

        do {
            _ = try VolumeNameBuilder.build(
                VolumeNameRequest(
                    cameraLetter: "AB",
                    rollNumber: "001",
                    reuseCount: nil,
                    includeReuseCount: false,
                    duplicateIndex: nil,
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
                    reuseCount: nil,
                    includeReuseCount: false,
                    duplicateIndex: nil,
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

        let uuidlessSonyVolume = MountedVolume(
            name: "Untitled",
            originalName: "Untitled",
            path: "/Volumes/Untitled UUIDless",
            bsdNode: "disk10s1",
            volumeUUID: nil,
            mediaUUID: nil,
            isRemovable: true,
            isInternal: false,
            freeBytes: 1,
            totalBytes: 2,
            isGenericName: true,
            fileSystem: "EXFAT",
            accessLevel: .inspectionOnly,
            isReadOnly: false
        )
        let uuidlessSonyCandidate = RenameCandidate(volume: uuidlessSonyVolume, scan: scanA)
        precondition(
            !uuidlessSonyCandidate.canBeBatchApproved,
            "A UUID-less Sony card must require deliberate manual execution"
        )
        precondition(
            !uuidlessSonyCandidate.isSafeForAutomaticApproval(among: [uuidlessSonyCandidate]),
            "A UUID-less Sony card must never enter automatic approval"
        )

        let sameTargetScanA = ScanResult(
            suggestedName: "A001", cameraLetter: "A", rollNumber: "001", suffix: nil,
            deviceType: "Sony FX3", clipCount: 2, totalFileCount: 4,
            firstClipName: "A001C001.MP4", lastClipName: "A001C002.MP4",
            isHighConfidence: true
        )
        let sameTargetScanB = ScanResult(
            suggestedName: "A001", cameraLetter: "A", rollNumber: "001", suffix: nil,
            deviceType: "Sony FX3", clipCount: 2, totalFileCount: 4,
            firstClipName: "A001C101.MP4", lastClipName: "A001C102.MP4",
            isHighConfidence: true
        )
        let sameTargetCandidateA = RenameCandidate(volume: duplicateUUIDA, scan: sameTargetScanA)
        let sameTargetCandidateB = RenameCandidate(volume: duplicateUUIDB, scan: sameTargetScanB)
        precondition(
            sameTargetCandidateA.canBeBatchApproved && sameTargetCandidateB.canBeBatchApproved,
            "Each card remains individually high-confidence before the shared target is considered"
        )
        precondition(
            !sameTargetCandidateA.isSafeForAutomaticApproval(among: [sameTargetCandidateA, sameTargetCandidateB]),
            "Different FX3 cards that both resolve to A001 must not auto-rename or batch approve"
        )
        precondition(
            !sameTargetCandidateB.isSafeForAutomaticApproval(among: [sameTargetCandidateA, sameTargetCandidateB]),
            "The target-name conflict must block both cards symmetrically"
        )

        var manuallySeparatedCandidateB = sameTargetCandidateB
        manuallySeparatedCandidateB.requestedName = "B001"
        precondition(
            sameTargetCandidateA.isSafeForAutomaticApproval(among: [sameTargetCandidateA, manuallySeparatedCandidateB]),
            "Automatic eligibility should return after the operator assigns distinct volume names"
        )
        precondition(
            manuallySeparatedCandidateB.isSafeForAutomaticApproval(among: [sameTargetCandidateA, manuallySeparatedCandidateB]),
            "The manually separated card should also become eligible"
        )

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

        var staleClone = clonedCandidateB
        staleClone.state = .stale
        precondition(
            clonedCandidateA.isSafeForAutomaticApproval(among: [clonedCandidateA, staleClone]),
            "An offline stale record must not block the currently mounted card"
        )

        let replacementVolume = MountedVolume(
            name: "Untitled", originalName: "Untitled", path: "/Volumes/Untitled",
            bsdNode: "disk4s1", volumeUUID: "DUPLICATE", mediaUUID: nil,
            mountSessionID: "replacement-session",
            isRemovable: true, isInternal: false, freeBytes: 1, totalBytes: 2,
            isGenericName: true, fileSystem: "EXFAT"
        )
        let replacementCandidate = RenameCandidate(volume: replacementVolume, scan: scanA)
        precondition(replacementVolume.id == "replacement-session", "A mount session must replace reusable BSD/UUID identity")
        precondition(!candidateA.hasSameMountedIdentity(as: replacementCandidate), "A replacement card in the same slot must not inherit the previous mounted identity")

        precondition(
            AutomaticRenameReviewPolicy.reason(
                isAutoRenameEnabled: true,
                canAutomaticallyRename: false,
                isGenericVolumeName: false,
                isHighConfidenceScan: true
            ) == nil,
            "Read-only UDF/HDE media must not be mislabeled as an unknown device"
        )
        precondition(
            AutomaticRenameReviewPolicy.reason(
                isAutoRenameEnabled: true,
                canAutomaticallyRename: true,
                isGenericVolumeName: true,
                isHighConfidenceScan: false
            ) == .lowConfidence,
            "A writable low-confidence scan must request camera/media review"
        )
        precondition(
            AutomaticRenameReviewPolicy.reason(
                isAutoRenameEnabled: true,
                canAutomaticallyRename: true,
                isGenericVolumeName: false,
                isHighConfidenceScan: true
            ) == .standardizedVolumeName,
            "A writable standardized volume name must request overwrite confirmation without calling the device unknown"
        )

        print("RenameApprovalModelsTests: PASS")
    }
}

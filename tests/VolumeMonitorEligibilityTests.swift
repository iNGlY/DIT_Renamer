import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct VolumeMonitorEligibilityTests {
    static func main() {
        let refreshCoordinator = VolumeRefreshCoordinator<Int>()
        var deliveredValues: [Int] = []
        var appliedValues: [Int] = []
        let firstRequest = refreshCoordinator.begin { deliveredValues.append($0) }
        let secondRequest = refreshCoordinator.begin(completion: nil)
        require(
            firstRequest.shouldStart && !secondRequest.shouldStart,
            "Concurrent volume refresh requests must collapse into one active scan and one trailing scan"
        )
        let trailingGeneration = refreshCoordinator.finish(
            generation: firstRequest.generation,
            makeValue: { 1 },
            apply: { appliedValues.append($0) }
        )
        require(
            trailingGeneration == secondRequest.generation && appliedValues.isEmpty && deliveredValues.isEmpty,
            "A superseded scan must start the trailing generation without applying data or losing explicit completions"
        )
        let noFurtherRefresh = refreshCoordinator.finish(
            generation: secondRequest.generation,
            makeValue: { 2 },
            apply: { appliedValues.append($0) }
        )
        require(
            noFurtherRefresh == nil && appliedValues == [2] && deliveredValues == [2],
            "The trailing scan must apply once and complete all waiting manual refresh callbacks with its latest result"
        )

        require(
            VolumeMonitor.isEligibleExternalMedia(
                diskInternal: nil,
                diskRemovable: nil,
                diskExternal: true,
                foundationRemovable: nil,
                foundationInternal: nil
            ),
            "An explicitly external CFexpress reader must remain eligible when Internal is absent"
        )
        require(
            !VolumeMonitor.isEligibleExternalMedia(
                diskInternal: true,
                diskRemovable: true,
                diskExternal: true,
                foundationRemovable: true,
                foundationInternal: false
            ),
            "An internal disk must always be rejected"
        )
        require(
            !VolumeMonitor.isEligibleExternalMedia(
                diskInternal: nil,
                diskRemovable: nil,
                diskExternal: nil,
                foundationRemovable: nil,
                foundationInternal: nil
            ),
            "Unknown media identity must remain a hard stop"
        )
        require(
            VolumeMonitor.isEligibleExternalMedia(
                diskInternal: false,
                diskRemovable: nil,
                diskExternal: nil,
                foundationRemovable: true,
                foundationInternal: false
            ),
            "Foundation removable evidence may admit a confirmed non-internal reader"
        )
        require(
            VolumeMonitor.resolvedVolumeName(
                diskVolumeName: "Untitled",
                mountURL: URL(fileURLWithPath: "/Volumes/Untitled 1")
            ) == "Untitled",
            "A collision-suffixed mount directory must not replace the real camera-card volume label"
        )
        require(
            VolumeMonitor.resolvedVolumeName(
                diskVolumeName: nil,
                mountURL: URL(fileURLWithPath: "/Volumes/Fallback Card")
            ) == "Fallback Card",
            "The mount directory remains a safe fallback when diskutil omits VolumeName"
        )

        require(
            VolumeMonitor.accessLevel(
                volumeUUID: nil,
                hasDiskIdentity: true,
                isCodexCompanion: false
            ) == .inspectionOnly,
            "A real external card without VolumeUUID must remain visible for inspection"
        )
        require(
            VolumeMonitor.accessLevel(
                volumeUUID: "SONY-EXFAT-UUID",
                hasDiskIdentity: true,
                isCodexCompanion: false
            ) == .renameCapable,
            "A normal Sony CFexpress exFAT card with UUID must retain rename capability"
        )
        require(
            VolumeMonitor.accessLevel(
                volumeUUID: nil,
                hasDiskIdentity: false,
                isCodexCompanion: true
            ) == .codexCompanionReadOnly,
            "A verified Codex HDE companion must remain visible without diskutil identity"
        )
        require(
            VolumeMonitor.accessLevel(
                volumeUUID: nil,
                hasDiskIdentity: false,
                isCodexCompanion: false
            ) == nil,
            "An arbitrary identity-less mount must remain excluded"
        )

        let mountedPaths: Set<String> = [
            "/Volumes/E_0004_1D6M",
            "/Volumes/E_0004_1D6M_hde"
        ]
        require(
            VolumeMonitor.isCodexHDECompanion(
                path: "/Volumes/E_0004_1D6M_hde",
                fileSystem: "X2XFUSE",
                mountedPaths: mountedPaths
            ),
            "The real Codex UDF plus _hde mount pair must be recognized"
        )
        require(
            !VolumeMonitor.isCodexHDECompanion(
                path: "/Volumes/Remote_hde",
                fileSystem: "X2XFUSE",
                mountedPaths: ["/Volumes/Remote_hde"]
            ),
            "A standalone FUSE mount must not be trusted as Codex media"
        )

        let sonyWithUUID = MountedVolume(
            name: "Untitled",
            originalName: "Untitled",
            path: "/Volumes/Untitled",
            bsdNode: "disk8s1",
            volumeUUID: "SONY-EXFAT-UUID",
            mediaUUID: "SONY-MEDIA-UUID",
            isRemovable: true,
            isInternal: false,
            freeBytes: 1,
            totalBytes: 2,
            isGenericName: true,
            fileSystem: "EXFAT",
            accessLevel: .renameCapable
        )
        let sonyWithoutUUID = MountedVolume(
            name: "Untitled",
            originalName: "Untitled",
            path: "/Volumes/Untitled 1",
            bsdNode: "disk9s1",
            volumeUUID: nil,
            mediaUUID: nil,
            isRemovable: true,
            isInternal: false,
            freeBytes: 1,
            totalBytes: 2,
            isGenericName: true,
            fileSystem: "EXFAT",
            accessLevel: .inspectionOnly
        )
        require(sonyWithUUID.canAttemptManualRename, "A normal Sony CFA card must allow manual renaming")
        require(sonyWithUUID.canAutomaticallyRename, "A normal Sony CFA card must keep automatic functionality")
        require(sonyWithoutUUID.canAttemptManualRename, "A writable UUID-less Sony CFA card must still allow manual renaming")
        require(!sonyWithoutUUID.canAutomaticallyRename, "A UUID-less Sony CFA card must not enter automatic or batch execution")

        let diskListFixture: [String: Any] = [
            "AllDisksAndPartitions": [
                [
                    "DeviceIdentifier": "disk12",
                    "Partitions": [
                        [
                            "DeviceIdentifier": "disk12s1",
                            "VolumeName": "DJI Mavic4",
                            "Content": "Windows_FAT_32"
                        ],
                        [
                            "DeviceIdentifier": "disk12s2",
                            "VolumeName": "Other Data",
                            "Content": "Windows_FAT_32"
                        ]
                    ]
                ],
                [
                    "DeviceIdentifier": "disk13s1",
                    "VolumeName": "Osmo360",
                    "Content": "Windows_FAT_32"
                ],
                [
                    "DeviceIdentifier": "disk14",
                    "VolumeName": "Osmo Action",
                    "Content": "Windows_FAT_32"
                ],
                [
                    "DeviceIdentifier": "disk15s1",
                    "VolumeName": "Osmo Action",
                    "MountPoint": "/Volumes/Osmo Action",
                    "Content": "Windows_FAT_32"
                ]
            ]
        ]
        let djiCandidates = DJIAutoMountPolicy.unmountedCandidates(from: diskListFixture)
        require(
            djiCandidates == [
                DJIAutoMountCandidate(bsdNode: "disk12s1", volumeName: "DJI Mavic4"),
                DJIAutoMountCandidate(bsdNode: "disk13s1", volumeName: "Osmo360"),
                DJIAutoMountCandidate(bsdNode: "disk14", volumeName: "Osmo Action")
            ],
            "Recognized DJI direct-connect volumes should support both partition and whole-disk BSD nodes while excluding mounted volumes"
        )
        require(
            DJIAutoMountPolicy.isSafeToMount(
                candidate: djiCandidates[0],
                actualBSDNode: "disk12s1",
                actualVolumeName: "DJI Mavic4",
                mountPoint: nil,
                isInternal: false,
                isRemovable: nil,
                isExternal: true,
                busProtocol: "USB",
                isAppleDiskImage: false
            ),
            "A matching external DJI direct-connect partition should be mountable"
        )
        require(
            !DJIAutoMountPolicy.isSafeToMount(
                candidate: djiCandidates[0],
                actualBSDNode: "disk12s1",
                actualVolumeName: "DJI Mavic4",
                mountPoint: nil,
                isInternal: true,
                isRemovable: true,
                isExternal: true,
                busProtocol: "USB",
                isAppleDiskImage: false
            ),
            "An internal disk must never be auto-mounted even if its label matches the DJI allowlist"
        )
        require(
            !DJIAutoMountPolicy.isSafeToMount(
                candidate: djiCandidates[0],
                actualBSDNode: "disk12s1",
                actualVolumeName: "DJI Mavic4",
                mountPoint: nil,
                isInternal: false,
                isRemovable: nil,
                isExternal: nil,
                busProtocol: "USB",
                isAppleDiskImage: false
            ),
            "Unknown device identity must fail closed before auto-mount"
        )
        require(
            !DJIAutoMountPolicy.isSafeToMount(
                candidate: djiCandidates[0],
                actualBSDNode: "disk12s1",
                actualVolumeName: "DJI Mavic4",
                mountPoint: nil,
                isInternal: false,
                isRemovable: true,
                isExternal: true,
                busProtocol: "Thunderbolt",
                isAppleDiskImage: false
            ),
            "The direct-connect allowlist must be limited to USB devices"
        )
        print("VolumeMonitorEligibilityTests passed")
    }
}

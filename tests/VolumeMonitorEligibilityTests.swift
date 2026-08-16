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
        print("VolumeMonitorEligibilityTests passed")
    }
}

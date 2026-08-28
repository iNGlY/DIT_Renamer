import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func volume(name: String, path: String, bsdNode: String) -> MountedVolume {
    MountedVolume(
        name: name,
        originalName: name,
        path: path,
        bsdNode: bsdNode,
        volumeUUID: "UUID-\(bsdNode)",
        mediaUUID: nil,
        isRemovable: true,
        isInternal: false,
        freeBytes: 1,
        totalBytes: 2,
        isGenericName: true,
        fileSystem: "ExFAT"
    )
}

@main
struct MenuBarIgnoredVolumeTests {
    static func main() {
        let active = volume(name: "Untitled", path: "/Volumes/Untitled", bsdNode: "disk9s1")
        let ignored = volume(name: "A001", path: "/Volumes/A001", bsdNode: "disk10s1")

        let visible = MenuBarVolumeFilter.visibleVolumes(
            [active, ignored],
            ignoredPaths: [ignored.path]
        )

        require(visible.map(\.path) == [active.path], "An ignored main-window volume must be absent from the menu-bar card list")
        require(
            MenuBarVolumeFilter.visibleVolumes([ignored], ignoredPaths: [ignored.path]).isEmpty,
            "The menu-bar card list must be empty when every mounted volume is ignored"
        )

        let ignoredRule = IgnoredVolumeRule(volume: ignored)
        let renamedMount = volume(name: "A001", path: "/Volumes/A001 1", bsdNode: "disk10s1")
        let identityVisible = MenuBarVolumeFilter.visibleVolumes(
            [active, renamedMount],
            ignoredRules: [ignoredRule]
        )
        require(
            identityVisible.map(\.path) == [active.path],
            "An ignored card must remain hidden when macOS changes its mount path after rename/remount"
        )
        let mediaIdentifiedIgnored = MountedVolume(
            name: "A001",
            originalName: "A001",
            path: "/Volumes/A001 Media",
            bsdNode: "disk10s1",
            volumeUUID: ignored.volumeUUID,
            mediaUUID: "CLONED-MEDIA-UUID",
            isRemovable: true,
            isInternal: false,
            freeBytes: 1,
            totalBytes: 2,
            isGenericName: false,
            fileSystem: "ExFAT"
        )
        let clonedOtherReader = MountedVolume(
            name: "A001",
            originalName: "A001",
            path: "/Volumes/A001 2",
            bsdNode: "disk11s1",
            volumeUUID: ignored.volumeUUID,
            mediaUUID: mediaIdentifiedIgnored.mediaUUID,
            isRemovable: true,
            isInternal: false,
            freeBytes: 1,
            totalBytes: 2,
            isGenericName: false,
            fileSystem: "ExFAT"
        )
        require(
            MenuBarVolumeFilter.visibleVolumes(
                [clonedOtherReader],
                ignoredRules: [IgnoredVolumeRule(volume: mediaIdentifiedIgnored)]
            ).count == 1,
            "Ignoring one card must not hide a cloned UUID card mounted through another reader"
        )

        print("MenuBarIgnoredVolumeTests: PASS")
    }
}

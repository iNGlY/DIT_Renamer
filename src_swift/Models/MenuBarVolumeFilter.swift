import Foundation

enum MenuBarVolumeFilter {
    static func visibleVolumes(
        _ volumes: [MountedVolume],
        ignoredPaths: Set<String>
    ) -> [MountedVolume] {
        volumes.filter { !ignoredPaths.contains($0.path) }
    }
}

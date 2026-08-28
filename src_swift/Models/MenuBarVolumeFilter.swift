import Foundation

struct IgnoredVolumeRule: Codable, Hashable {
    let path: String
    let bsdNode: String
    let volumeUUID: String?
    let mediaUUID: String?

    init(volume: MountedVolume) {
        path = volume.path
        bsdNode = volume.bsdNode
        volumeUUID = Self.normalizedIdentifier(volume.volumeUUID)
        mediaUUID = Self.normalizedIdentifier(volume.mediaUUID)
    }

    func matches(_ volume: MountedVolume) -> Bool {
        guard bsdNode == volume.bsdNode else { return false }
        if let mediaUUID {
            return mediaUUID == Self.normalizedIdentifier(volume.mediaUUID)
        }
        if let volumeUUID {
            return volumeUUID == Self.normalizedIdentifier(volume.volumeUUID)
        }
        return path == volume.path
    }

    private static func normalizedIdentifier(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .uppercased() ?? ""
        return normalized.isEmpty ? nil : normalized
    }
}

enum MenuBarVolumeFilter {
    static func visibleVolumes(
        _ volumes: [MountedVolume],
        ignoredPaths: Set<String>
    ) -> [MountedVolume] {
        volumes.filter { !ignoredPaths.contains($0.path) }
    }

    static func visibleVolumes(
        _ volumes: [MountedVolume],
        ignoredRules: Set<IgnoredVolumeRule>
    ) -> [MountedVolume] {
        volumes.filter { volume in
            !ignoredRules.contains { $0.matches(volume) }
        }
    }

    static func visibleVolumes(
        _ volumes: [MountedVolume],
        ignoredPaths: Set<String>,
        ignoredRules: Set<IgnoredVolumeRule>
    ) -> [MountedVolume] {
        let identityBackedPaths = Set(ignoredRules.map(\.path))
        let legacyIgnoredPaths = ignoredPaths.subtracting(identityBackedPaths)
        return volumes.filter { volume in
            !legacyIgnoredPaths.contains(volume.path)
                && !ignoredRules.contains { $0.matches(volume) }
        }
    }
}

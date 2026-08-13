import Combine
import Foundation

@MainActor
final class IgnoredVolumeStore: ObservableObject {
    static let shared = IgnoredVolumeStore()

    @Published private(set) var paths: Set<String>

    private let defaults = UserDefaults.standard
    private let storageKey = "ignoredVolumePaths"

    private init() {
        let data = defaults.data(forKey: storageKey) ?? Data()
        paths = (try? JSONDecoder().decode(Set<String>.self, from: data)) ?? []
    }

    func isIgnored(_ volume: MountedVolume) -> Bool {
        paths.contains(volume.path)
    }

    func setIgnored(_ ignored: Bool, volume: MountedVolume) {
        var updated = paths
        if ignored {
            updated.insert(volume.path)
        } else {
            updated.remove(volume.path)
        }
        guard updated != paths else { return }
        paths = updated
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(paths) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

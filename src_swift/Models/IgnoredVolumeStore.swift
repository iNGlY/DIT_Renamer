import Combine
import Foundation

@MainActor
final class IgnoredVolumeStore: ObservableObject {
    static let shared = IgnoredVolumeStore()

    @Published private(set) var paths: Set<String>
    @Published private(set) var rules: Set<IgnoredVolumeRule>

    private let defaults = UserDefaults.standard
    private let storageKey = "ignoredVolumePaths"
    private let rulesStorageKey = "ignoredVolumeRulesV2"

    private init() {
        let data = defaults.data(forKey: storageKey) ?? Data()
        paths = (try? JSONDecoder().decode(Set<String>.self, from: data)) ?? []
        let rulesData = defaults.data(forKey: rulesStorageKey) ?? Data()
        rules = (try? JSONDecoder().decode(Set<IgnoredVolumeRule>.self, from: rulesData)) ?? []
    }

    func isIgnored(_ volume: MountedVolume) -> Bool {
        let pathHasIdentityRule = rules.contains { $0.path == volume.path }
        let matchesLegacyPath = paths.contains(volume.path) && !pathHasIdentityRule
        return matchesLegacyPath || rules.contains { $0.matches(volume) }
    }

    func setIgnored(_ ignored: Bool, volume: MountedVolume) {
        var updatedPaths = paths
        var updatedRules = rules
        if ignored {
            updatedPaths.insert(volume.path)
            updatedRules.insert(IgnoredVolumeRule(volume: volume))
        } else {
            let matchingRules = updatedRules.filter { $0.matches(volume) }
            updatedPaths.remove(volume.path)
            for rule in matchingRules {
                updatedPaths.remove(rule.path)
                updatedRules.remove(rule)
            }
        }
        guard updatedPaths != paths || updatedRules != rules else { return }
        paths = updatedPaths
        rules = updatedRules
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(paths) {
            defaults.set(data, forKey: storageKey)
        }
        if let data = try? JSONEncoder().encode(rules) {
            defaults.set(data, forKey: rulesStorageKey)
        }
    }
}

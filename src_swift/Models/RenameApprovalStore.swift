import Foundation
import Combine

@MainActor
public final class RenameApprovalStore: ObservableObject {
    public static let shared = RenameApprovalStore()

    @Published public private(set) var candidates: [RenameCandidate] = []

    private let fileManager = FileManager.default
    private let fileURL: URL

    private init() {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("DITRenamer", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("rename_approval_queue_v1.json")
        load()
    }

    public func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([RenameCandidate].self, from: data) else { return }
        candidates = decoded.filter { $0.state == .pending || $0.state == .failed }
    }

    public func upsert(_ candidate: RenameCandidate) {
        if let index = candidates.firstIndex(where: { $0.hasSameMediaIdentity(as: candidate) }) {
            let existing = candidates[index]
            guard existing.effectiveName != candidate.effectiveName
                    || existing.bsdNode != candidate.bsdNode
                    || existing.mountPath != candidate.mountPath else { return }
            candidates[index] = candidate
        } else {
            candidates.append(candidate)
        }
        persist()
    }

    public func update(_ candidate: RenameCandidate) {
        guard let index = candidates.firstIndex(where: { $0.id == candidate.id }) else { return }
        candidates[index] = candidate
        persist()
    }

    public func remove(id: UUID) {
        candidates.removeAll { $0.id == id }
        persist()
    }

    public func clearCompletedIdentity(volumeUUID: String, firstClipName: String?, lastClipName: String?) {
        candidates.removeAll {
            $0.volumeUUID == volumeUUID && $0.firstClipName == firstClipName && $0.lastClipName == lastClipName
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(candidates) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

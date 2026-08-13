import Foundation

public enum RenameApprovalState: String, Codable, Hashable {
    case pending
    case approving
    case failed
    case stale
}

public enum RenameExecutionPath: CaseIterable, Hashable {
    case automatic
    case suggestedApproval
    case batchApproval
    case manualAssignment
}

public enum RenameOperationPolicy {
    public static func allowsExecution(
        via path: RenameExecutionPath,
        isScanning: Bool
    ) -> Bool {
        _ = path
        return !isScanning
    }
}

public struct VolumeNameRequest: Codable, Hashable {
    public var cameraLetter: String
    public var rollNumber: String
    public var reuseCount: Int?
    public var includeReuseCount: Bool
    public var duplicateIndex: Int?
    public var suffix: String?
    public var includeSuffix: Bool

    public init(
        cameraLetter: String,
        rollNumber: String,
        reuseCount: Int?,
        includeReuseCount: Bool,
        duplicateIndex: Int?,
        suffix: String?,
        includeSuffix: Bool
    ) {
        self.cameraLetter = cameraLetter
        self.rollNumber = rollNumber
        self.reuseCount = reuseCount
        self.includeReuseCount = includeReuseCount
        self.duplicateIndex = duplicateIndex
        self.suffix = suffix
        self.includeSuffix = includeSuffix
    }

    public var recordedReuseCount: Int? {
        includeReuseCount ? reuseCount : nil
    }
}

public struct RenameCandidate: Identifiable, Codable, Hashable {
    public let id: UUID
    public let volumeUUID: String
    public let mediaUUID: String?
    public let mountSessionID: String?
    public let bsdNode: String
    public let mountPath: String
    public let originalName: String
    public let fileSystem: String
    public let deviceType: String
    public let firstClipName: String?
    public let lastClipName: String?
    public let clipCount: Int
    public let totalFileCount: Int
    public let usedSpace: String
    public let suggestedName: String?
    public let suffix: String?
    public let isHighConfidence: Bool
    public let isUnformatted: Bool
    public let isEmptyCard: Bool
    public let isPhotoOnly: Bool
    public let isUnconfiguredCamera: Bool
    public var requestedName: String?
    public var state: RenameApprovalState
    public var lastError: String?
    public let createdAt: Date

    public init(id: UUID = UUID(), volume: MountedVolume, scan: ScanResult, requestedName: String? = nil) {
        self.id = id
        self.volumeUUID = volume.volumeUUID ?? ""
        self.mediaUUID = volume.mediaUUID
        self.mountSessionID = volume.mountSessionID
        self.bsdNode = volume.bsdNode
        self.mountPath = volume.path
        self.originalName = volume.originalName
        self.fileSystem = volume.fileSystem
        self.deviceType = scan.deviceType
        self.firstClipName = scan.firstClipName
        self.lastClipName = scan.lastClipName
        self.clipCount = scan.clipCount
        self.totalFileCount = scan.totalFileCount
        self.usedSpace = volume.usedGBFormatted
        self.suggestedName = scan.suggestedName
        self.suffix = scan.suffix
        self.isHighConfidence = scan.isHighConfidence
        self.isUnformatted = scan.isUnformattedCard
        self.isEmptyCard = scan.isEmptyCard
        self.isPhotoOnly = scan.isPhotoOnly
        self.isUnconfiguredCamera = scan.isUnconfiguredCamera
        self.requestedName = requestedName ?? scan.suggestedName
        self.state = .pending
        self.lastError = nil
        self.createdAt = Date()
    }

    public var effectiveName: String? { requestedName ?? suggestedName }

    public var hasGenericOriginalName: Bool {
        let normalized = originalName.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .uppercased()
        return MountedVolume.genericNames.contains(normalized)
    }

    public var canBeBatchApproved: Bool {
        state == .pending && isHighConfidence && !isUnformatted && !isEmptyCard &&
            !isPhotoOnly && !isUnconfiguredCamera && effectiveName != nil
    }

    public var identityKey: String {
        "\(volumeUUID)|\(firstClipName ?? "")|\(lastClipName ?? "")"
    }

    public var mountedIdentityKey: String {
        "\(identityKey)|\(bsdNode)|\(mountSessionID ?? "NO-SESSION")"
    }

    public func hasSameMediaIdentity(as other: RenameCandidate) -> Bool {
        identityKey == other.identityKey
    }

    public func hasSameMountedIdentity(as other: RenameCandidate) -> Bool {
        mountedIdentityKey == other.mountedIdentityKey
    }

    public var normalizedEffectiveName: String? {
        guard let effectiveName else { return nil }
        let normalized = effectiveName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalized.isEmpty ? nil : normalized
    }

    public func hasConflictingTargetName(
        among candidates: [RenameCandidate],
        occupiedNames: Set<String> = []
    ) -> Bool {
        guard let targetName = normalizedEffectiveName else { return false }
        if occupiedNames.contains(targetName) { return true }
        return candidates.contains { other in
            other.id != id
                && other.state != .stale
                && !hasSameMountedIdentity(as: other)
                && other.normalizedEffectiveName == targetName
        }
    }

    public func isSafeForAutomaticApproval(
        among candidates: [RenameCandidate],
        occupiedNames: Set<String> = []
    ) -> Bool {
        guard canBeBatchApproved, hasGenericOriginalName else { return false }
        guard !hasConflictingTargetName(among: candidates, occupiedNames: occupiedNames) else { return false }
        return !candidates.contains { other in
            other.id != id
                && other.state != .stale
                && hasSameMediaIdentity(as: other)
                && !hasSameMountedIdentity(as: other)
        }
    }
}

@MainActor
final class AutomaticRenameQueue {
    nonisolated static let defaultInitialStabilizationNanoseconds: UInt64 = 1_000_000_000
    nonisolated static let defaultInterOperationDelayNanoseconds: UInt64 = 1_000_000_000

    private var candidateIDs: [UUID] = []
    private var enqueuedIDs = Set<UUID>()
    private let initialStabilizationNanoseconds: UInt64
    private let interOperationDelayNanoseconds: UInt64
    private(set) var isProcessing = false

    var pendingCount: Int { candidateIDs.count }

    init(
        initialStabilizationNanoseconds: UInt64 = AutomaticRenameQueue.defaultInitialStabilizationNanoseconds,
        interOperationDelayNanoseconds: UInt64 = AutomaticRenameQueue.defaultInterOperationDelayNanoseconds
    ) {
        self.initialStabilizationNanoseconds = initialStabilizationNanoseconds
        self.interOperationDelayNanoseconds = interOperationDelayNanoseconds
    }

    func enqueue(
        _ candidateID: UUID,
        operation: @escaping @MainActor (UUID) async -> Void
    ) {
        guard enqueuedIDs.insert(candidateID).inserted else { return }
        candidateIDs.append(candidateID)
        guard !isProcessing else { return }

        isProcessing = true
        Task { [weak self] in
            await self?.drain(operation: operation)
        }
    }

    private func drain(operation: @escaping @MainActor (UUID) async -> Void) async {
        if initialStabilizationNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: initialStabilizationNanoseconds)
        }
        while !candidateIDs.isEmpty {
            let candidateID = candidateIDs.removeFirst()
            await operation(candidateID)
            enqueuedIDs.remove(candidateID)
            if !candidateIDs.isEmpty, interOperationDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: interOperationDelayNanoseconds)
            }
        }
        isProcessing = false
    }
}

public struct RenameExecutionResult: Identifiable, Hashable {
    public let id = UUID()
    public let candidateID: UUID
    public let success: Bool
    public let message: String
    public let actualName: String?

    public init(candidateID: UUID, success: Bool, message: String, actualName: String?) {
        self.candidateID = candidateID
        self.success = success
        self.message = message
        self.actualName = actualName
    }
}

public enum VolumeNameError: LocalizedError, Hashable {
    case invalidCameraLetter
    case invalidRollNumber
    case invalidReuseCount
    case missingReuseCount
    case invalidDuplicateIndex
    case tooLong(fileSystem: String)
    case invalidCharacters

    public var errorDescription: String? {
        switch self {
        case .invalidCameraLetter: return "机位标识必须是一个大写字母。"
        case .invalidRollNumber: return "卷号必须由数字组成。"
        case .invalidReuseCount: return "复用次数不能小于 0。"
        case .missingReuseCount: return "已开启复用次数记录，请输入有效数字。"
        case .invalidDuplicateIndex: return "重复机位编号必须大于 0。"
        case .tooLong(let fileSystem): return "\(fileSystem) 卷名最多 11 个字符。"
        case .invalidCharacters: return "卷名仅允许大写字母、数字、下划线和连字符。"
        }
    }
}

public enum VolumeNameBuilder {
    public static func build(_ request: VolumeNameRequest, fileSystem: String = "") throws -> String {
        let letter = request.cameraLetter.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard letter.range(of: "^[A-Z]$", options: .regularExpression) != nil else {
            throw VolumeNameError.invalidCameraLetter
        }

        let roll = request.rollNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard roll.range(of: "^[0-9]+$", options: .regularExpression) != nil else {
            throw VolumeNameError.invalidRollNumber
        }
        if request.includeReuseCount {
            guard let reuseCount = request.reuseCount else { throw VolumeNameError.missingReuseCount }
            guard reuseCount >= 0 else { throw VolumeNameError.invalidReuseCount }
        }
        if let duplicateIndex = request.duplicateIndex, duplicateIndex < 1 {
            throw VolumeNameError.invalidDuplicateIndex
        }

        var name = "\(letter)\(roll)"
        if let duplicateIndex = request.duplicateIndex { name += "_\(duplicateIndex)" }
        if request.includeSuffix, let suffix = request.suffix, !suffix.isEmpty { name += suffix.uppercased() }

        guard name.range(of: "^[A-Z0-9_-]+$", options: .regularExpression) != nil else {
            throw VolumeNameError.invalidCharacters
        }
        let lowerFileSystem = fileSystem.lowercased()
        if (lowerFileSystem.contains("fat") || lowerFileSystem.contains("ms-dos")) && name.count > 11 {
            throw VolumeNameError.tooLong(fileSystem: fileSystem.isEmpty ? "FAT/exFAT" : fileSystem)
        }
        return name
    }
}

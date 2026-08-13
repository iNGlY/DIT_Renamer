import Foundation

public struct RenamerPrinterAuditDocument: Codable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let records: [RenamerPrinterAuditRecord]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case records
    }
}

public struct RenamerPrinterAuditRecord: Codable {
    public let renameID: UUID
    public let renamedAt: Date
    public let originalName: String
    public let actualName: String
    public let requestedName: String?
    public let reuseCount: Int?
    public let duplicateIndex: Int?
    public let volumeUUID: String?
    public let mediaUUID: String?
    public let bsdNode: String?
    public let recordedMountPath: String?
    public let deviceType: String
    public let firstClipName: String?
    public let lastClipName: String?
    public let clipCount: Int

    enum CodingKeys: String, CodingKey {
        case renameID = "rename_id"
        case renamedAt = "renamed_at"
        case originalName = "original_name"
        case actualName = "actual_name"
        case requestedName = "requested_name"
        case reuseCount = "reuse_count"
        case duplicateIndex = "duplicate_index"
        case volumeUUID = "volume_uuid"
        case mediaUUID = "media_uuid"
        case bsdNode = "bsd_node"
        case recordedMountPath = "recorded_mount_path"
        case deviceType = "device_type"
        case firstClipName = "first_clip_name"
        case lastClipName = "last_clip_name"
        case clipCount = "clip_count"
    }

    init(_ item: RenameHistoryItem) {
        renameID = item.id
        renamedAt = item.timestamp
        originalName = item.originalName
        actualName = item.newName
        requestedName = item.requestedName
        reuseCount = item.reuseCount
        duplicateIndex = item.duplicateIndex
        volumeUUID = item.volumeUUID
        mediaUUID = item.mediaUUID
        bsdNode = item.bsdNode
        recordedMountPath = item.mountedPath
        deviceType = item.deviceType
        firstClipName = item.firstClipName
        lastClipName = item.lastClipName
        clipCount = item.clipCount
    }
}

public enum RenamerPrinterAuditExport {
    public static let schemaVersion = 1
    public static let fileName = "printer_audit_v1.json"

    public static func fileURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("DITRenamer", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    public static func write(_ items: [RenameHistoryItem], fileManager: FileManager = .default) throws {
        let document = RenamerPrinterAuditDocument(
            schemaVersion: schemaVersion,
            generatedAt: Date(),
            records: items.map(RenamerPrinterAuditRecord.init)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: fileURL(fileManager: fileManager), options: .atomic)
    }
}

import Foundation

struct RenamerAuditReference: Codable, Equatable {
    let renameID: UUID
    let renamedAt: Date
    let actualName: String
    let volumeUUID: String?
    let deviceType: String
    let lastClipName: String?

    enum CodingKeys: String, CodingKey {
        case renameID = "rename_id"
        case renamedAt = "renamed_at"
        case actualName = "actual_name"
        case volumeUUID = "volume_uuid"
        case deviceType = "device_type"
        case lastClipName = "last_clip_name"
    }
}

enum RenamerAuditReader {
    private struct Document: Decodable {
        let schemaVersion: Int
        let records: [Record]

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case records
        }
    }

    private struct Record: Decodable {
        let renameID: UUID
        let renamedAt: Date
        let actualName: String
        let requestedName: String?
        let volumeUUID: String?
        let recordedMountPath: String?
        let deviceType: String
        let lastClipName: String?

        enum CodingKeys: String, CodingKey {
            case renameID = "rename_id"
            case renamedAt = "renamed_at"
            case actualName = "actual_name"
            case requestedName = "requested_name"
            case volumeUUID = "volume_uuid"
            case recordedMountPath = "recorded_mount_path"
            case deviceType = "device_type"
            case lastClipName = "last_clip_name"
        }

        func reference() -> RenamerAuditReference {
            RenamerAuditReference(
                renameID: renameID,
                renamedAt: renamedAt,
                actualName: actualName,
                volumeUUID: volumeUUID,
                deviceType: deviceType,
                lastClipName: lastClipName
            )
        }
    }

    static func latestMatch(sourceVolumePath: String?, auditFileURL: URL = auditURL()) -> RenamerAuditReference? {
        guard let sourceVolumePath,
              !sourceVolumePath.isEmpty,
              let data = try? Data(contentsOf: auditFileURL) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let document = try? decoder.decode(Document.self, from: data),
              document.schemaVersion == 1 else {
            return nil
        }

        let normalizedPath = URL(fileURLWithPath: sourceVolumePath).standardizedFileURL.path
        let volumeName = URL(fileURLWithPath: normalizedPath).lastPathComponent
        return document.records
            .filter {
                $0.recordedMountPath == normalizedPath
                    || $0.actualName.caseInsensitiveCompare(volumeName) == .orderedSame
                    || $0.requestedName?.caseInsensitiveCompare(volumeName) == .orderedSame
            }
            .max { $0.renamedAt < $1.renamedAt }
            .map { $0.reference() }
    }

    private static func auditURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DITRenamer/printer_audit_v1.json")
    }
}

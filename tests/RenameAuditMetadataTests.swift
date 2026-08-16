import Foundation

@main
struct RenameAuditMetadataTests {
    static func main() throws {
        let withoutReuse = RenameHistoryItem(
            originalName: "Untitled",
            newName: "A001_1",
            firstClipName: "A001C101.MP4",
            lastClipName: "A001C102.MP4",
            clipCount: 2,
            totalFileCount: 4,
            usedSpace: "1.0 GB",
            deviceType: "Sony FX3",
            timestamp: Date(timeIntervalSince1970: 0),
            dateDayString: "1970-01-01",
            requestedName: "A001_1",
            reuseCount: nil,
            duplicateIndex: 1
        )
        let withReuse = RenameHistoryItem(
            originalName: "Untitled",
            newName: "B001",
            firstClipName: "B001C001.MP4",
            lastClipName: "B001C002.MP4",
            clipCount: 2,
            totalFileCount: 4,
            usedSpace: "1.0 GB",
            deviceType: "Sony FX3",
            timestamp: Date(timeIntervalSince1970: 0),
            dateDayString: "1970-01-01",
            requestedName: "B001",
            reuseCount: 2,
            duplicateIndex: nil,
            volumeUUID: "VOL-B001",
            mediaUUID: "MEDIA-B001",
            bsdNode: "disk5s1",
            mountedPath: "/Volumes/Untitled",
            fileSystem: "exfat",
            isHighConfidence: true,
            isPhotoOnly: false,
            isUnconfiguredCamera: false,
            cameraMetadataEvidence: CameraMetadataEvidence(
                manufacturer: "Sony",
                exactModel: "FX3",
                productFamily: "Sony Cinema Line",
                source: .sonyNonRealTimeMeta,
                confidence: .high,
                isCameraNative: true,
                sourceFileName: "A001C001M01.XML"
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let documentWithoutReuse = RenamerPrinterAuditDocument(
            schemaVersion: 1,
            generatedAt: Date(timeIntervalSince1970: 0),
            records: [RenamerPrinterAuditRecord(withoutReuse)]
        )
        let withoutReuseJSON = String(data: try encoder.encode(documentWithoutReuse), encoding: .utf8)!
        precondition(!withoutReuseJSON.contains("reuse_count"), "Reuse metadata must be omitted when the operator leaves the feature disabled")
        precondition(withoutReuseJSON.contains("duplicate_index"), "The explicit duplicate-camera marker should remain auditable")

        let documentWithReuse = RenamerPrinterAuditDocument(
            schemaVersion: 1,
            generatedAt: Date(timeIntervalSince1970: 0),
            records: [RenamerPrinterAuditRecord(withReuse)]
        )
        let withReuseJSON = String(data: try encoder.encode(documentWithReuse), encoding: .utf8)!
        precondition(withReuseJSON.contains("\"reuse_count\":2"), "Enabled reuse metadata must be exported")

        let documentV2 = RenamerPrinterAuditDocumentV2(
            schemaVersion: 2,
            generatedAt: Date(timeIntervalSince1970: 0),
            records: [RenamerPrinterAuditRecordV2(withReuse)]
        )
        let v2JSON = String(data: try encoder.encode(documentV2), encoding: .utf8)!
        precondition(v2JSON.contains("\"schema_version\":2"), "Printer audit v2 must advertise schema version 2")
        precondition(v2JSON.contains("\"total_file_count\":4"), "Printer audit v2 must include total file count")
        precondition(v2JSON.contains("\"used_space\":\"1.0 GB\""), "Printer audit v2 must include used space")
        precondition(v2JSON.contains("\"file_system\":\"exfat\""), "Printer audit v2 must include file system")
        precondition(v2JSON.contains("\"media_uuid\":\"MEDIA-B001\""), "Printer audit v2 must include media identity")
        precondition(v2JSON.contains("\"camera_metadata_evidence\""), "Printer audit v2 must retain camera metadata evidence")
        precondition(v2JSON.contains("\"sony-non-real-time-meta\""), "Printer audit v2 must retain the sidecar source")
        precondition(!v2JSON.contains("/Volumes/"), "Camera metadata evidence must not leak an absolute source path")

        let pdfWithoutReuse = RenameAuditFormatting.pdfReuseHeaderHTML(items: [withoutReuse], isChinese: true)
        precondition(pdfWithoutReuse.isEmpty, "PDF must omit the reuse-count column when no record contains reuse metadata")
        let csvWithoutReuse = RenameAuditFormatting.csvDocument(items: [withoutReuse])
        precondition(!csvWithoutReuse.contains("Card Reuse Count"), "CSV must omit the reuse-count column when disabled")

        let pdfWithReuse = RenameAuditFormatting.pdfReuseHeaderHTML(items: [withReuse], isChinese: true)
        precondition(pdfWithReuse.contains("卡片复用次数"), "Chinese PDF must include the localized reuse-count column when enabled")
        precondition(
            RenameAuditFormatting.pdfReuseCellHTML(item: withReuse, includeColumn: true).contains(">2<"),
            "PDF reuse-count cells must contain the recorded value"
        )
        let csvWithReuse = RenameAuditFormatting.csvDocument(items: [withReuse])
        precondition(csvWithReuse.contains("Card Reuse Count"), "CSV must include the reuse-count column when enabled")
        precondition(csvWithReuse.contains("\"2\""), "CSV must contain the recorded reuse count")

        print("RenameAuditMetadataTests: PASS")
    }
}

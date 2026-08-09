import AppKit
import Foundation

enum PrintHistoryFormat {
    case csv
    case json

    var fileExtension: String { self == .csv ? "csv" : "json" }
    var title: String { self == .csv ? "Export CSV history" : "Export JSON history" }
}

@MainActor
enum PrintHistoryExporter {
    static func export(_ jobs: [DITPrinterJob], format: PrintHistoryFormat) throws {
        let panel = NSSavePanel()
        panel.title = format.title
        panel.nameFieldStringValue = "DIT-Printer-History-\(fileDate()).\(format.fileExtension)"
        panel.allowedContentTypes = format == .csv ? [.commaSeparatedText] : [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data: Data
        switch format {
        case .json:
            data = try DITPrinterDateCodec.encoder.encode(jobs)
        case .csv:
            data = csv(jobs).data(using: .utf8) ?? Data()
        }
        try data.write(to: url, options: .atomic)
    }

    private static func csv(_ jobs: [DITPrinterJob]) -> String {
        let header = [
            "job_id", "status", "signal_source", "signal_received_at", "copy_completed_at",
            "bin_name", "last_asset_name", "reuse_count", "source_volume_path", "template",
            "profile", "output_kind", "queue", "submission_response", "printed_at", "error"
        ]
        var rows = [header.map(escape).joined(separator: ",")]
        for job in jobs.sorted(by: { $0.receivedAt > $1.receivedAt }) {
            let row = [
                job.id.uuidString, job.status.rawValue, job.signalSource, timestamp(job.receivedAt),
                timestamp(job.copyCompletedAt), job.binName, job.lastAssetName, job.reuseCount.map(String.init) ?? "",
                job.sourceVolumePath ?? "", job.labelTemplate?.name ?? "", job.printProfile?.name ?? "",
                job.printProfile?.outputKind.rawValue ?? "", job.queueName ?? "", job.cupsJobReference ?? "",
                job.printedAt.map(timestamp) ?? "", job.lastError ?? ""
            ]
            rows.append(row.map(escape).joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    private static func escape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func fileDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

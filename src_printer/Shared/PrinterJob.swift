import Foundation

struct LabelTemplate: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var widthMm: Double
    var heightMm: Double
    var gapMm: Double

    static let defaultTemplate = LabelTemplate(
        id: "builtin-72x51",
        name: "72 x 51 mm",
        widthMm: 72,
        heightMm: 51,
        gapMm: 3
    )

    static let builtIns = [
        defaultTemplate,
        LabelTemplate(id: "builtin-60x40", name: "60 x 40 mm", widthMm: 60, heightMm: 40, gapMm: 3),
        LabelTemplate(id: "builtin-50x30", name: "50 x 30 mm", widthMm: 50, heightMm: 30, gapMm: 3),
        LabelTemplate(id: "builtin-80x50", name: "80 x 50 mm", widthMm: 80, heightMm: 50, gapMm: 3)
    ]

    var isBuiltIn: Bool { id.hasPrefix("builtin-") }

    var widthDots: Int {
        let rawDots = Int((widthMm / 25.4 * 203).rounded())
        return max(8, ((rawDots + 7) / 8) * 8)
    }

    var heightDots: Int {
        max(96, Int((heightMm / 25.4 * 203).rounded()))
    }

    var bytesPerRow: Int { widthDots / 8 }

    var tsplSize: String {
        "SIZE \(formatMillimeters(widthMm)) mm,\(formatMillimeters(heightMm)) mm"
    }

    var tsplGap: String {
        "GAP \(formatMillimeters(gapMm)) mm,0 mm"
    }

    private func formatMillimeters(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

enum DITPrinterJobStatus: String, Codable {
    case pending
    case printing
    case printed
    case failed
}

struct DITPrinterJob: Codable, Identifiable, Equatable {
    let id: UUID
    var binName: String
    var lastAssetName: String
    var copyCompletedAt: Date
    let receivedAt: Date
    var reuseCount: Int?
    var status: DITPrinterJobStatus
    var printedAt: Date?
    var queueName: String?
    var labelTemplate: LabelTemplate?
    var cupsJobReference: String?
    var lastError: String?
    var renamerAudit: RenamerAuditReference?

    init(
        id: UUID = UUID(),
        binName: String,
        lastAssetName: String,
        copyCompletedAt: Date,
        receivedAt: Date = Date(),
        reuseCount: Int? = nil,
        status: DITPrinterJobStatus = .pending,
        printedAt: Date? = nil,
        queueName: String? = nil,
        labelTemplate: LabelTemplate? = nil,
        cupsJobReference: String? = nil,
        lastError: String? = nil,
        renamerAudit: RenamerAuditReference? = nil
    ) {
        self.id = id
        self.binName = binName
        self.lastAssetName = lastAssetName
        self.copyCompletedAt = copyCompletedAt
        self.receivedAt = receivedAt
        self.reuseCount = reuseCount
        self.status = status
        self.printedAt = printedAt
        self.queueName = queueName
        self.labelTemplate = labelTemplate
        self.cupsJobReference = cupsJobReference
        self.lastError = lastError
        self.renamerAudit = renamerAudit
    }

    static func jobsDirectory(fileManager: FileManager = .default) throws -> URL {
        if let overridePath = ProcessInfo.processInfo.environment["DIT_PRINTER_DATA_DIRECTORY"],
           !overridePath.isEmpty {
            let directory = URL(fileURLWithPath: overridePath, isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base
            .appendingPathComponent("DIT Printer", isDirectory: true)
            .appendingPathComponent("Jobs", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func fileURL(fileManager: FileManager = .default) throws -> URL {
        try Self.jobsDirectory(fileManager: fileManager)
            .appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }
}

enum DITPrinterJobStoreError: LocalizedError {
    case invalidManifest(String)

    var errorDescription: String? {
        switch self {
        case .invalidManifest(let message): return message
        }
    }
}

enum DITPrinterDateCodec {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

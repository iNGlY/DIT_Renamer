import Foundation

enum LabelField: String, Codable, CaseIterable, Identifiable, Hashable {
    case binName
    case lastAssetName
    case copyCompletedAt
    case reuseCount
    case signalSource
    case signalReceivedAt
    case sourceVolume
    case customNote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .binName: return "BIN"
        case .lastAssetName: return "LAST ASSET"
        case .copyCompletedAt: return "COPY COMPLETE"
        case .reuseCount: return "CARD REUSE"
        case .signalSource: return "SIGNAL SOURCE"
        case .signalReceivedAt: return "RECEIVED"
        case .sourceVolume: return "SOURCE VOLUME"
        case .customNote: return "NOTE"
        }
    }
}

struct LabelTemplate: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var widthMm: Double
    var heightMm: Double
    var gapMm: Double
    var title: String
    var footer: String
    var customNote: String
    var enabledFields: [LabelField]

    static let defaultTemplate = LabelTemplate(
        id: "builtin-72x51",
        name: "72 x 51 mm",
        widthMm: 72,
        heightMm: 51,
        gapMm: 3,
        title: "DIT PRINTER",
        footer: "Silverstack signal recorded",
        customNote: "",
        enabledFields: [.binName, .lastAssetName, .copyCompletedAt, .reuseCount]
    )

    static let builtIns = [
        defaultTemplate,
        LabelTemplate(id: "builtin-60x40", name: "60 x 40 mm", widthMm: 60, heightMm: 40, gapMm: 3, title: "DIT PRINTER", footer: "Silverstack signal recorded", customNote: "", enabledFields: [.binName, .lastAssetName, .copyCompletedAt, .reuseCount]),
        LabelTemplate(id: "builtin-50x30", name: "50 x 30 mm", widthMm: 50, heightMm: 30, gapMm: 3, title: "DIT PRINTER", footer: "Silverstack signal recorded", customNote: "", enabledFields: [.binName, .lastAssetName, .copyCompletedAt, .reuseCount]),
        LabelTemplate(id: "builtin-40x30", name: "40 x 30 mm (compact)", widthMm: 40, heightMm: 30, gapMm: 3, title: "DIT PRINTER", footer: "Silverstack signal recorded", customNote: "", enabledFields: [.binName, .lastAssetName, .reuseCount]),
        LabelTemplate(id: "builtin-80x50", name: "80 x 50 mm", widthMm: 80, heightMm: 50, gapMm: 3, title: "DIT PRINTER", footer: "Silverstack signal recorded", customNote: "", enabledFields: [.binName, .lastAssetName, .copyCompletedAt, .reuseCount])
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

    private enum CodingKeys: String, CodingKey {
        case id, name, widthMm, heightMm, gapMm, title, footer, customNote, enabledFields
    }

    init(
        id: String,
        name: String,
        widthMm: Double,
        heightMm: Double,
        gapMm: Double,
        title: String = "DIT PRINTER",
        footer: String = "Silverstack signal recorded",
        customNote: String = "",
        enabledFields: [LabelField] = [.binName, .lastAssetName, .copyCompletedAt, .reuseCount]
    ) {
        self.id = id
        self.name = name
        self.widthMm = widthMm
        self.heightMm = heightMm
        self.gapMm = gapMm
        self.title = title
        self.footer = footer
        self.customNote = customNote
        self.enabledFields = enabledFields
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        widthMm = try values.decode(Double.self, forKey: .widthMm)
        heightMm = try values.decode(Double.self, forKey: .heightMm)
        gapMm = try values.decode(Double.self, forKey: .gapMm)
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? "DIT PRINTER"
        footer = try values.decodeIfPresent(String.self, forKey: .footer) ?? "Silverstack signal recorded"
        customNote = try values.decodeIfPresent(String.self, forKey: .customNote) ?? ""
        enabledFields = try values.decodeIfPresent([LabelField].self, forKey: .enabledFields)
            ?? [.binName, .lastAssetName, .copyCompletedAt, .reuseCount]
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
    var printProfile: PrintProfile?
    var cupsJobReference: String?
    var lastError: String?
    var renamerAudit: RenamerAuditReference?
    var signalSource: String
    var sourceVolumePath: String?

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
        printProfile: PrintProfile? = nil,
        cupsJobReference: String? = nil,
        lastError: String? = nil,
        renamerAudit: RenamerAuditReference? = nil,
        signalSource: String = "Silverstack Copy Job (Verify Included)",
        sourceVolumePath: String? = nil
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
        self.printProfile = printProfile
        self.cupsJobReference = cupsJobReference
        self.lastError = lastError
        self.renamerAudit = renamerAudit
        self.signalSource = signalSource
        self.sourceVolumePath = sourceVolumePath
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

    private enum CodingKeys: String, CodingKey {
        case id, binName, lastAssetName, copyCompletedAt, receivedAt, reuseCount, status, printedAt
        case queueName, labelTemplate, printProfile, cupsJobReference, lastError, renamerAudit
        case signalSource, sourceVolumePath
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        binName = try values.decode(String.self, forKey: .binName)
        lastAssetName = try values.decode(String.self, forKey: .lastAssetName)
        copyCompletedAt = try values.decode(Date.self, forKey: .copyCompletedAt)
        receivedAt = try values.decode(Date.self, forKey: .receivedAt)
        reuseCount = try values.decodeIfPresent(Int.self, forKey: .reuseCount)
        status = try values.decode(DITPrinterJobStatus.self, forKey: .status)
        printedAt = try values.decodeIfPresent(Date.self, forKey: .printedAt)
        queueName = try values.decodeIfPresent(String.self, forKey: .queueName)
        labelTemplate = try values.decodeIfPresent(LabelTemplate.self, forKey: .labelTemplate)
        printProfile = try values.decodeIfPresent(PrintProfile.self, forKey: .printProfile)
        cupsJobReference = try values.decodeIfPresent(String.self, forKey: .cupsJobReference)
        lastError = try values.decodeIfPresent(String.self, forKey: .lastError)
        renamerAudit = try values.decodeIfPresent(RenamerAuditReference.self, forKey: .renamerAudit)
        signalSource = try values.decodeIfPresent(String.self, forKey: .signalSource)
            ?? "Silverstack Copy Job (Verify Included)"
        sourceVolumePath = try values.decodeIfPresent(String.self, forKey: .sourceVolumePath)
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

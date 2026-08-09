import Combine
import Foundation

enum PrintOutputKind: String, Codable, CaseIterable, Identifiable {
    case cupsRawTSPL
    case cupsPDF
    case customCLI

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cupsRawTSPL: return "CUPS Raw command"
        case .cupsPDF: return "CUPS PDF"
        case .customCLI: return "Custom CLI"
        }
    }
}

enum PrinterCommandLanguage: String, Codable, CaseIterable, Identifiable {
    case tspl
    case zpl
    case epl
    case cpcl
    case pdf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tspl: return "TSPL (TSC / M325F)"
        case .zpl: return "ZPL (Zebra)"
        case .epl: return "EPL / EPL2 (Eltron / Zebra)"
        case .cpcl: return "CPCL (Zebra mobile)"
        case .pdf: return "PDF (CUPS / generic)"
        }
    }

    var fileExtension: String {
        switch self {
        case .tspl: return "tspl"
        case .zpl: return "zpl"
        case .epl: return "epl"
        case .cpcl: return "cpcl"
        case .pdf: return "pdf"
        }
    }

    var isRawCommand: Bool { self != .pdf }
}

struct PrintProfile: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var outputKind: PrintOutputKind
    var printerLanguage: PrinterCommandLanguage
    var queueName: String
    var executablePath: String
    var arguments: [String]

    static let defaultProfile = PrintProfile(
        id: "builtin-cups-pdf",
        name: "Generic CUPS PDF label printer",
        outputKind: .cupsPDF,
        printerLanguage: .pdf,
        queueName: "",
        executablePath: "",
        arguments: []
    )

    static let builtIns = [
        defaultProfile,
        PrintProfile(id: "builtin-raw-tspl", name: "TSPL label printer (M325F and compatible)", outputKind: .cupsRawTSPL, printerLanguage: .tspl, queueName: "", executablePath: "", arguments: [])
    ]

    var isBuiltIn: Bool { id.hasPrefix("builtin-") }

    init(
        id: String,
        name: String,
        outputKind: PrintOutputKind,
        printerLanguage: PrinterCommandLanguage? = nil,
        queueName: String,
        executablePath: String,
        arguments: [String]
    ) {
        self.id = id
        self.name = name
        self.outputKind = outputKind
        self.printerLanguage = printerLanguage ?? (outputKind == .cupsPDF ? .pdf : .tspl)
        self.queueName = queueName
        self.executablePath = executablePath
        self.arguments = arguments
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, outputKind, printerLanguage, queueName, executablePath, arguments
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        outputKind = try values.decode(PrintOutputKind.self, forKey: .outputKind)
        printerLanguage = try values.decodeIfPresent(PrinterCommandLanguage.self, forKey: .printerLanguage)
            ?? (outputKind == .cupsPDF ? .pdf : .tspl)
        queueName = try values.decode(String.self, forKey: .queueName)
        executablePath = try values.decode(String.self, forKey: .executablePath)
        arguments = try values.decode([String].self, forKey: .arguments)
    }
}

@MainActor
final class PrintProfileStore: ObservableObject {
    @Published private(set) var profiles: [PrintProfile]
    @Published var selectedProfileID: String {
        didSet { UserDefaults.standard.set(selectedProfileID, forKey: Self.selectedProfileKey) }
    }

    private static let customProfilesKey = "ditPrinter.customPrintProfiles"
    private static let selectedProfileKey = "ditPrinter.selectedPrintProfile"

    init() {
        let custom = (UserDefaults.standard.data(forKey: Self.customProfilesKey))
            .flatMap { try? JSONDecoder().decode([PrintProfile].self, from: $0) } ?? []
        let allProfiles = PrintProfile.builtIns + custom.filter { !$0.isBuiltIn }
        profiles = allProfiles
        let savedID = UserDefaults.standard.string(forKey: Self.selectedProfileKey) ?? PrintProfile.defaultProfile.id
        selectedProfileID = allProfiles.contains(where: { $0.id == savedID }) ? savedID : PrintProfile.defaultProfile.id
    }

    var selectedProfile: PrintProfile {
        profiles.first(where: { $0.id == selectedProfileID }) ?? PrintProfile.defaultProfile
    }

    func save(
        name: String,
        outputKind: PrintOutputKind,
        printerLanguage: PrinterCommandLanguage,
        queueName: String,
        executablePath: String,
        argumentsText: String
    ) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQueue = queueName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExecutable = executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let arguments = argumentsText.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
        guard !trimmedName.isEmpty else { return "Enter a profile name." }
        if outputKind != .customCLI, trimmedQueue.isEmpty { return "Select or enter a CUPS queue." }
        if outputKind == .cupsPDF, printerLanguage != .pdf { return "CUPS PDF output must use PDF language." }
        if outputKind == .cupsRawTSPL, !printerLanguage.isRawCommand { return "CUPS Raw output requires TSPL, ZPL, EPL, or CPCL." }
        if outputKind == .customCLI {
            guard trimmedExecutable.hasPrefix("/") else { return "Custom CLI executable must be an absolute path." }
            guard arguments.contains("{file}") else { return "Custom CLI arguments must contain {file} on its own line." }
        }

        let existing = selectedProfile
        let profile = PrintProfile(
            id: existing.isBuiltIn ? "custom-\(UUID().uuidString)" : existing.id,
            name: trimmedName,
            outputKind: outputKind,
            printerLanguage: printerLanguage,
            queueName: trimmedQueue,
            executablePath: trimmedExecutable,
            arguments: arguments
        )
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        selectedProfileID = profile.id
        persistCustomProfiles()
        return nil
    }

    func deleteSelectedCustomProfile() {
        guard !selectedProfile.isBuiltIn else { return }
        profiles.removeAll { $0.id == selectedProfileID }
        selectedProfileID = PrintProfile.defaultProfile.id
        persistCustomProfiles()
    }

    private func persistCustomProfiles() {
        guard let data = try? JSONEncoder().encode(profiles.filter { !$0.isBuiltIn }) else { return }
        UserDefaults.standard.set(data, forKey: Self.customProfilesKey)
    }
}

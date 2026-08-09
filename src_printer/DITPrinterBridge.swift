import Foundation

private struct IncomingManifest: Decodable {
    let jobID: String?
    let binName: String
    let lastAssetName: String
    let copyCompletedAt: Date
    let sourceVolumePath: String?

    enum CodingKeys: String, CodingKey {
        case jobID = "job_id"
        case binName = "bin_name"
        case lastAssetName = "last_asset_name"
        case copyCompletedAt = "copy_completed_at"
        case sourceVolumePath = "source_volume_path"
    }
}

private enum BridgeError: LocalizedError {
    case usage
    case missingManifest(String)
    case invalidManifest(String)

    var errorDescription: String? {
        switch self {
        case .usage: return "Usage: DITPrinterBridge --manifest /absolute/path/to/dit-printer.json"
        case .missingManifest(let path): return "Manifest does not exist: \(path)"
        case .invalidManifest(let reason): return "Invalid DIT Printer manifest: \(reason)"
        }
    }
}

private func parseManifestURL() throws -> URL {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count == 2, arguments[0] == "--manifest" else { throw BridgeError.usage }
    let url = URL(fileURLWithPath: arguments[1])
    guard FileManager.default.fileExists(atPath: url.path) else { throw BridgeError.missingManifest(url.path) }
    return url
}

private func decodeManifest(at url: URL) throws -> IncomingManifest {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    do {
        let manifest = try decoder.decode(IncomingManifest.self, from: Data(contentsOf: url))
        guard !manifest.binName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BridgeError.invalidManifest("bin_name is empty")
        }
        guard !manifest.lastAssetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BridgeError.invalidManifest("last_asset_name is empty")
        }
        return manifest
    } catch let error as BridgeError {
        throw error
    } catch {
        throw BridgeError.invalidManifest(error.localizedDescription)
    }
}

private func launchApplication() {
    guard ProcessInfo.processInfo.environment["DIT_PRINTER_SKIP_LAUNCH"] != "1" else { return }
    let open = Process()
    open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    open.arguments = ["-a", "DIT Printer"]
    try? open.run()
}

private func stableUUID(for value: String) -> UUID {
    func fnv1a64(_ input: String, salt: UInt64) -> UInt64 {
        var hash = 1_469_598_103_934_665_603 ^ salt
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    let first = fnv1a64(value, salt: 0xA861_5B6C_D901_48E3)
    let second = fnv1a64(value, salt: 0x034B_75F2_AE16_9C80)
    let hex = String(format: "%016llX%016llX", first, second)
    let formatted = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20))"
    return UUID(uuidString: formatted)!
}

@main
struct DITPrinterBridge {
    static func main() {
        do {
            let manifest = try decodeManifest(at: parseManifestURL())
            let job = DITPrinterJob(
                id: manifest.jobID.map(stableUUID(for:)) ?? UUID(),
                binName: manifest.binName,
                lastAssetName: manifest.lastAssetName,
                copyCompletedAt: manifest.copyCompletedAt,
                renamerAudit: RenamerAuditReader.latestMatch(sourceVolumePath: manifest.sourceVolumePath)
            )
            let destination = try job.fileURL()
            if !FileManager.default.fileExists(atPath: destination.path) {
                try DITPrinterDateCodec.encoder.encode(job).write(to: destination, options: .atomic)
                print("queued \(job.id.uuidString)")
            } else {
                print("already queued \(job.id.uuidString)")
            }
            launchApplication()
        } catch {
            FileHandle.standardError.write(Data("DITPrinterBridge: \(error.localizedDescription)\n".utf8))
            exit(2)
        }
    }
}

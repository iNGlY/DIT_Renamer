import Foundation

private enum ParaShootConfiguration {
    static let cliPath = "/Applications/ParaShoot.app/Contents/MacOS/cli/parashoot"
}

private struct VerifyEraseManifest: Decodable {
    let jobID: String
    let cardPath: String
    let verifiedDestinationPath: String
    let verifiedAt: Date

    enum CodingKeys: String, CodingKey {
        case jobID = "job_id"
        case cardPath = "card_path"
        case verifiedDestinationPath = "verified_destination_path"
        case verifiedAt = "verified_at"
    }
}

private struct EraseAudit: Codable {
    let jobID: String
    let cardPath: String
    let verifiedDestinationPath: String
    let verifiedAt: Date
    let requestedAt: Date
    let completedAt: Date
    let cardBSDNode: String
    let cardVolumeUUID: String?
    let status: String
    let exitCode: Int32
    let standardOutput: String
    let standardError: String
}

private struct DiskIdentity {
    let bsdNode: String
    let volumeUUID: String?
}

private struct CommandResult {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String
}

private enum EraseBridgeError: LocalizedError {
    case usage
    case invalidManifest(String)
    case unsafeCardPath(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: ParaShootEraseBridge --manifest /absolute/path/to/verified-erase.json"
        case .invalidManifest(let reason), .unsafeCardPath(let reason), .commandFailed(let reason):
            return reason
        }
    }
}

private func manifestURL() throws -> URL {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count == 2, arguments[0] == "--manifest" else { throw EraseBridgeError.usage }
    let url = URL(fileURLWithPath: arguments[1])
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw EraseBridgeError.invalidManifest("Manifest does not exist: \(url.path)")
    }
    return url
}

private func readManifest(at url: URL) throws -> VerifyEraseManifest {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    do {
        let manifest = try decoder.decode(VerifyEraseManifest.self, from: Data(contentsOf: url))
        guard !manifest.jobID.isEmpty else { throw EraseBridgeError.invalidManifest("job_id is empty") }
        guard !manifest.cardPath.isEmpty else { throw EraseBridgeError.invalidManifest("card_path is empty") }
        guard !manifest.verifiedDestinationPath.isEmpty else {
            throw EraseBridgeError.invalidManifest("verified_destination_path is empty")
        }
        return manifest
    } catch let error as EraseBridgeError {
        throw error
    } catch {
        throw EraseBridgeError.invalidManifest("Invalid manifest: \(error.localizedDescription)")
    }
}

private func resolveExistingDirectory(_ path: String, field: String) throws -> URL {
    let url = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw EraseBridgeError.invalidManifest("\(field) is not an existing directory: \(path)")
    }
    return url
}

private func cardIdentity(for cardURL: URL) throws -> DiskIdentity {
    guard cardURL.path.hasPrefix("/Volumes/") else {
        throw EraseBridgeError.unsafeCardPath("card_path must be the mounted card root under /Volumes.")
    }
    let result = try run(executable: "/usr/sbin/diskutil", arguments: ["info", "-plist", cardURL.path], timeout: 10)
    guard result.exitCode == 0,
          let data = result.standardOutput.data(using: .utf8),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
          let info = plist as? [String: Any] else {
        throw EraseBridgeError.unsafeCardPath("diskutil could not identify \(cardURL.path).")
    }
    guard info["RemovableMediaOrExternalDevice"] as? Bool == true,
          info["Internal"] as? Bool != true,
          let bsdNode = info["DeviceIdentifier"] as? String,
          !bsdNode.isEmpty else {
        throw EraseBridgeError.unsafeCardPath("card_path is not a removable external volume.")
    }
    return DiskIdentity(bsdNode: bsdNode, volumeUUID: info["VolumeUUID"] as? String)
}

private func run(executable: String, arguments: [String], timeout: TimeInterval) throws -> CommandResult {
    let process = Process()
    let output = Pipe()
    let error = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = error
    try process.run()

    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning && Date() < deadline {
        Thread.sleep(forTimeInterval: 0.05)
    }
    if process.isRunning {
        process.terminate()
        process.waitUntilExit()
        throw EraseBridgeError.commandFailed("\(URL(fileURLWithPath: executable).lastPathComponent) timed out.")
    }
    return CommandResult(
        exitCode: process.terminationStatus,
        standardOutput: String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
        standardError: String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    )
}

private func auditDirectory() throws -> URL {
    let base = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let directory = base
        .appendingPathComponent("DIT Printer", isDirectory: true)
        .appendingPathComponent("ParaShootEraseJobs", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func saveAudit(_ audit: EraseAudit) {
    do {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let filename = "\(audit.requestedAt.timeIntervalSince1970)-\(audit.jobID.hashValue).json"
        let url = try auditDirectory().appendingPathComponent(filename)
        try encoder.encode(audit).write(to: url, options: .atomic)
    } catch {
        FileHandle.standardError.write(Data("ParaShootEraseBridge: could not save audit: \(error.localizedDescription)\n".utf8))
    }
}

@main
struct ParaShootEraseBridge {
    static func main() {
        do {
            let manifest = try readManifest(at: manifestURL())
            guard FileManager.default.isExecutableFile(atPath: ParaShootConfiguration.cliPath) else {
                throw EraseBridgeError.commandFailed("ParaShoot CLI was not found at \(ParaShootConfiguration.cliPath).")
            }
            let cardURL = try resolveExistingDirectory(manifest.cardPath, field: "card_path")
            let destinationURL = try resolveExistingDirectory(manifest.verifiedDestinationPath, field: "verified_destination_path")
            guard cardURL != destinationURL else {
                throw EraseBridgeError.unsafeCardPath("The verified destination cannot be the source card.")
            }
            let identity = try cardIdentity(for: cardURL)

            let cardCheck = try run(executable: ParaShootConfiguration.cliPath, arguments: ["is-card", cardURL.path], timeout: 20)
            guard cardCheck.exitCode == 0 else {
                throw EraseBridgeError.unsafeCardPath("ParaShoot does not recognize \(cardURL.path) as a card. \(cardCheck.standardError)")
            }

            let result = try run(
                executable: ParaShootConfiguration.cliPath,
                arguments: [
                    "erase",
                    "--card", cardURL.path,
                    "--destinations", destinationURL.path,
                    "--min-destinations", "1",
                    "--no-auto-add-shuttle-drives",
                    "--machine-readable"
                ],
                timeout: 60 * 60
            )
            let audit = EraseAudit(
                jobID: manifest.jobID,
                cardPath: cardURL.path,
                verifiedDestinationPath: destinationURL.path,
                verifiedAt: manifest.verifiedAt,
                requestedAt: Date(),
                completedAt: Date(),
                cardBSDNode: identity.bsdNode,
                cardVolumeUUID: identity.volumeUUID,
                status: result.exitCode == 0 ? "erased" : "failed",
                exitCode: result.exitCode,
                standardOutput: result.standardOutput,
                standardError: result.standardError
            )
            saveAudit(audit)
            guard result.exitCode == 0 else {
                throw EraseBridgeError.commandFailed(result.standardError.isEmpty ? "ParaShoot erase failed." : result.standardError)
            }
            print("ParaShoot erase completed for \(identity.bsdNode)")
        } catch {
            FileHandle.standardError.write(Data("ParaShootEraseBridge: \(error.localizedDescription)\n".utf8))
            exit(2)
        }
    }
}

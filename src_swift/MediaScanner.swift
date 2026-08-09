import Foundation

public class MediaScanner {
    private static let exifToolCandidates = [
        "/opt/homebrew/bin/exiftool",
        "/usr/local/bin/exiftool"
    ]

    public static var exifToolPath: String? {
        exifToolCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static func scan(volumePath: String) -> ScanResult {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: volumePath)
        let shouldInspectCameraMetadata = UserDefaults.standard.object(forKey: "enableExifToolModelDetection") as? Bool ?? true
        let hasSonyStructure = fm.fileExists(atPath: url.appendingPathComponent("PRIVATE/M4ROOT").path)
            || fm.fileExists(atPath: url.appendingPathComponent("M4ROOT").path)
        
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return ScanResult(
                suggestedName: nil, cameraLetter: nil, rollNumber: nil, suffix: nil,
                deviceType: "Generic", clipCount: 0, totalFileCount: 0, firstClipName: nil, lastClipName: nil,
                isHighConfidence: false, isUnconfiguredCamera: false, isEmptyCard: true, isPhotoOnly: false, photoCount: 0
            )
        }
        
        var djiFolders: [String] = []
        var videoClips: [String] = []
        var photoClips: [String] = []
        var hasBraw: Bool = false
        var hasNev: Bool = false
        var hasR3d: Bool = false
        var hasAri: Bool = false
        var hasRdcFolder: Bool = false
        var hasRdmFolder: Bool = false
        var totalFileCount: Int = 0
        var metadataCandidateURL: URL?
        var sonyMetadataSidecars: [URL] = []
        
        var earliestDate: Date? = nil
        var latestDate: Date? = nil
        
        let videoExts: Set<String> = ["mov", "mp4", "mxf", "ari", "crm", "rdc", "r3d", "braw", "nev"]
        let photoExts: Set<String> = ["jpg", "jpeg", "png", "arw", "cr3", "cr2", "nef", "dng", "raf", "orf", "rw2", "tif", "tiff"]
        
        var arriRawBytes: Int64 = 0
        var nonRawBytes: Int64 = 0
        var scanTruncated = false
        
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            let ext = fileURL.pathExtension.lowercased()
            let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            
            if isDir {
                if name.lowercased().hasSuffix(".rdc") { hasRdcFolder = true }
                if name.lowercased().hasSuffix(".rdm") { hasRdmFolder = true }
                
                let range = NSRange(location: 0, length: name.utf16.count)
                let regex = try? NSRegularExpression(pattern: "^[A-Z]\\d{3}_[A-Z0-9]{4,8}$")
                if regex?.firstMatch(in: name, options: [], range: range) != nil {
                    djiFolders.append(name)
                }
            } else {
                totalFileCount += 1
                let fSize = Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)

                if hasSonyStructure,
                   sonyMetadataSidecars.count < 20,
                   (ext == "xml" || ext == "xmp"),
                   fSize > 0,
                   fSize <= 1_048_576 {
                    sonyMetadataSidecars.append(fileURL)
                }
                
                if videoExts.contains(ext) {
                    videoClips.append(name)
                    if metadataCandidateURL == nil || (ext == "mp4" && metadataCandidateURL?.pathExtension.lowercased() != "mp4") {
                        metadataCandidateURL = fileURL
                    }
                    if ext == "braw" { hasBraw = true }
                    if ext == "nev" { hasNev = true }
                    if ext == "r3d" { hasR3d = true }
                    
                    // Hardware-level binary MXF header inspection for ARRIRAW vs ProRes distinction
                    let isRaw = MediaScanner.isARRIRAWFile(fileURL: fileURL)
                    if isRaw {
                        hasAri = true
                        arriRawBytes += fSize
                    } else {
                        nonRawBytes += fSize
                    }
                } else if photoExts.contains(ext) {
                    photoClips.append(name)
                    nonRawBytes += fSize
                } else {
                    nonRawBytes += fSize
                }
                
                // Track modification dates for unformatted card detection
                if let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
                    if earliestDate == nil || modDate < earliestDate! { earliestDate = modDate }
                    if latestDate == nil || modDate > latestDate! { latestDate = modDate }
                }
            }
            
            if totalFileCount > 5000 {
                scanTruncated = true
                break
            }
        }
        
        videoClips.sort()
        let firstClip = videoClips.first
        let lastClip = videoClips.last
        let sonyModelFromSidecars = hasSonyStructure
            ? detectSonyModel(fromSidecars: sonyMetadataSidecars)
            : nil
        let needsExifToolInstallation = hasSonyStructure
            && sonyModelFromSidecars == nil
            && shouldInspectCameraMetadata
            && metadataCandidateURL != nil
            && exifToolPath == nil
        let sonyModel = sonyModelFromSidecars
            ?? (hasSonyStructure && shouldInspectCameraMetadata
                ? detectSonyModel(from: metadataCandidateURL)
                : nil)
        
        // Calculate date span for unformatted card check
        var dateSpanDays: Int = 0
        var earliestDateStr: String? = nil
        var latestDateStr: String? = nil
        
        if let minD = earliestDate, let maxD = latestDate {
            let seconds = maxD.timeIntervalSince(minD)
            dateSpanDays = Int(seconds / 86400.0)
            
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            earliestDateStr = df.string(from: minD)
            latestDateStr = df.string(from: maxD)
        }
        
        // 1. Check if empty card
        if totalFileCount == 0 && videoClips.isEmpty && photoClips.isEmpty {
            return ScanResult(
                suggestedName: nil, cameraLetter: nil, rollNumber: nil, suffix: nil,
                deviceType: "Empty Card", clipCount: 0, totalFileCount: 0,
                firstClipName: nil, lastClipName: nil,
                isHighConfidence: false, isUnconfiguredCamera: false, isEmptyCard: true, isPhotoOnly: false, photoCount: 0
            )
        }
        
        // 2. Check if photo-only card
        if videoClips.isEmpty && !photoClips.isEmpty {
            return ScanResult(
                suggestedName: nil, cameraLetter: nil, rollNumber: nil, suffix: nil,
                deviceType: "Photo Card", clipCount: 0, totalFileCount: totalFileCount,
                firstClipName: photoClips.first, lastClipName: photoClips.last,
                isHighConfidence: false, isUnconfiguredCamera: false, isEmptyCard: false, isPhotoOnly: true, photoCount: photoClips.count
            )
        }
        
        // 3. Check for DJI 4D Specific Folder Match
        if let djiFolder = djiFolders.first {
            let parts = djiFolder.components(separatedBy: "_")
            if parts.count >= 2 {
                let mainPart = parts[0]
                let suffix = "_" + parts[1]
                let camera = String(mainPart.prefix(1))
                let roll = String(mainPart.dropFirst())
                return ScanResult(
                    suggestedName: djiFolder,
                    cameraLetter: camera,
                    rollNumber: roll,
                    suffix: suffix,
                    deviceType: "DJI 4D",
                    clipCount: videoClips.count,
                    totalFileCount: totalFileCount,
                    firstClipName: firstClip,
                    lastClipName: lastClip,
                    isHighConfidence: false,
                    isScanComplete: !scanTruncated
                )
            }
        }
        
        // 4. Check clip files & camera models
        if let first = firstClip {
            let range = NSRange(location: 0, length: first.utf16.count)
            
            // A. DEFENSE: Check for Sony Default Unconfigured Clip Name (e.g., C0001.MP4, C0042.MOV)
            let unconfiguredRegex = try? NSRegularExpression(pattern: "^C\\d{4}\\.", options: [.caseInsensitive])
            if hasSonyStructure,
               unconfiguredRegex?.firstMatch(in: first, options: [], range: range) != nil {
                let isUnformatted = dateSpanDays >= 1
                return ScanResult(
                    suggestedName: nil, cameraLetter: nil, rollNumber: nil, suffix: nil,
                    deviceType: sonyModel.map { "Sony \($0) (Unconfigured Camera ID)" } ?? "Sony (Unconfigured Camera ID)",
                    clipCount: videoClips.count, totalFileCount: totalFileCount,
                    firstClipName: firstClip, lastClipName: lastClip,
                    isHighConfidence: false, isUnconfiguredCamera: true,
                    isEmptyCard: false, isPhotoOnly: false, photoCount: 0,
                    isUnformattedCard: isUnformatted, dateSpanDays: dateSpanDays,
                    earliestDateStr: earliestDateStr, latestDateStr: latestDateStr,
                    needsExifToolInstallation: needsExifToolInstallation
                )
            }
            
            // B. Sony FX Cinema (FX3 / FX6 / FX9 / VENICE) Pattern (e.g. B003C026_2001184O.MP4)
            let sonyFxRegex = try? NSRegularExpression(pattern: "^([A-Z])(\\d{3})[CR]\\d{3}_", options: [])
            if let match = sonyFxRegex?.firstMatch(in: first, options: [], range: range) {
                let camera = String(first[Range(match.range(at: 1), in: first)!])
                let roll = String(first[Range(match.range(at: 2), in: first)!])
                let suggested = "\(camera)\(roll)"
                let isUnformatted = dateSpanDays >= 2
                
                return ScanResult(
                    suggestedName: suggested, cameraLetter: camera, rollNumber: roll, suffix: nil,
                    deviceType: sonyModel.map { "Sony \($0)" } ?? "Sony FX Cinema",
                    clipCount: videoClips.count, totalFileCount: totalFileCount,
                    firstClipName: firstClip, lastClipName: lastClip,
                    isHighConfidence: hasSonyStructure && !scanTruncated, isUnconfiguredCamera: false,
                    isEmptyCard: false, isPhotoOnly: false, photoCount: 0,
                    isUnformattedCard: isUnformatted, dateSpanDays: dateSpanDays,
                    earliestDateStr: earliestDateStr, latestDateStr: latestDateStr,
                    needsExifToolInstallation: needsExifToolInstallation
                )
            }
            
            // C. Nikon ZR / Z Cinema Pattern (e.g. A001_C018_0731IT.MOV / .R3D / .NEV)
            // Format: CamID (1) + Roll (3) + _C + Clip (3) + _ + MMDD (4) + Hash (2)
            let nikonZrRegex = try? NSRegularExpression(pattern: "^([A-Z])(\\d{3})_C\\d{3}_(\\d{4})([A-Z0-9]{2})", options: [])
            if let match = nikonZrRegex?.firstMatch(in: first, options: [], range: range) {
                let camera = String(first[Range(match.range(at: 1), in: first)!])
                let roll = String(first[Range(match.range(at: 2), in: first)!])
                let suggested = "\(camera)\(roll)"
                
                let devName: String
                if hasNev {
                    devName = "Nikon ZR (N-RAW)"
                } else if hasR3d && !hasRdcFolder && !hasRdmFolder {
                    devName = "Nikon ZR (R3D RAW)"
                } else {
                    devName = "Nikon Cinema (ZR/Z9)"
                }
                
                let isUnformatted = dateSpanDays >= 2
                
                return ScanResult(
                    suggestedName: suggested, cameraLetter: camera, rollNumber: roll, suffix: nil,
                    deviceType: devName,
                    clipCount: videoClips.count, totalFileCount: totalFileCount,
                    firstClipName: firstClip, lastClipName: lastClip,
                    // The filename alone is not enough to identify a camera model.
                    isHighConfidence: false, isUnconfiguredCamera: false,
                    isEmptyCard: false, isPhotoOnly: false, photoCount: 0,
                    isUnformattedCard: isUnformatted, dateSpanDays: dateSpanDays,
                    earliestDateStr: earliestDateStr, latestDateStr: latestDateStr
                )
            }
            
            // D. Native RED Digital Cinema (Contains .RDC or .RDM folders)
            if hasRdcFolder || hasRdmFolder {
                let redRegex = try? NSRegularExpression(pattern: "^([A-Z])(\\d{3})_", options: [])
                var camera: String?
                var roll: String?
                if let match = redRegex?.firstMatch(in: first, options: [], range: range) {
                    camera = String(first[Range(match.range(at: 1), in: first)!])
                    roll = String(first[Range(match.range(at: 2), in: first)!])
                }
                let isUnformatted = dateSpanDays >= 2
                return ScanResult(
                    suggestedName: camera.flatMap { letter in roll.map { "\(letter)\($0)" } },
                    cameraLetter: camera, rollNumber: roll, suffix: nil,
                    deviceType: "RED Digital Cinema",
                    clipCount: videoClips.count, totalFileCount: totalFileCount,
                    firstClipName: firstClip, lastClipName: lastClip,
                    // RDC/RDM proves a RED media structure, not the Camera ID or Reel.
                    isHighConfidence: false, isUnconfiguredCamera: false,
                    isEmptyCard: false, isPhotoOnly: false, photoCount: 0,
                    isUnformattedCard: isUnformatted, dateSpanDays: dateSpanDays,
                    earliestDateStr: earliestDateStr, latestDateStr: latestDateStr
                )
            }
            
            // E. ARRI / Canon / Generic Standard Cinema Pattern with Underscore (e.g. A001_C001_07143X.MOV)
            let standardCinemaRegex = try? NSRegularExpression(pattern: "^([A-Z])(\\d{3})_", options: [])
            if let match = standardCinemaRegex?.firstMatch(in: first, options: [], range: range) {
                let camera = String(first[Range(match.range(at: 1), in: first)!])
                let roll = String(first[Range(match.range(at: 2), in: first)!])
                let suggested = "\(camera)\(roll)"
                let isUnformatted = dateSpanDays >= 2
                
                let device = hasBraw ? "Blackmagic Design" : "Cinema Card"
                let hde = HDECalculator.calculateHDE(volumePath: volumePath, hasAri: hasAri, deviceType: device, arriRawBytes: arriRawBytes, nonRawBytes: nonRawBytes)
                return ScanResult(
                    suggestedName: suggested, cameraLetter: camera, rollNumber: roll, suffix: nil,
                    deviceType: device,
                    clipCount: videoClips.count, totalFileCount: totalFileCount,
                    firstClipName: firstClip, lastClipName: lastClip,
                    // Generic A001_ names are shared by several camera families.
                    isHighConfidence: false, isUnconfiguredCamera: false,
                    isEmptyCard: false, isPhotoOnly: false, photoCount: 0,
                    isUnformattedCard: isUnformatted, dateSpanDays: dateSpanDays,
                    earliestDateStr: earliestDateStr, latestDateStr: latestDateStr,
                    hdeResult: hde
                )
            }
        }
        
        let isUnformatted = dateSpanDays >= 2
        let fallbackDevice = hasBraw ? "Blackmagic Design" : "Generic Media"
        let fallbackHde = HDECalculator.calculateHDE(volumePath: volumePath, hasAri: hasAri, deviceType: fallbackDevice, arriRawBytes: arriRawBytes, nonRawBytes: nonRawBytes)
        return ScanResult(
            suggestedName: nil, cameraLetter: nil, rollNumber: nil, suffix: nil,
            deviceType: "Unrecognized Media",
            clipCount: videoClips.count, totalFileCount: totalFileCount,
            firstClipName: firstClip, lastClipName: lastClip,
            isHighConfidence: false, isUnconfiguredCamera: false,
            isEmptyCard: false, isPhotoOnly: false, photoCount: 0,
            isUnformattedCard: isUnformatted, dateSpanDays: dateSpanDays,
            earliestDateStr: earliestDateStr, latestDateStr: latestDateStr,
            hdeResult: fallbackHde,
            isScanComplete: !scanTruncated,
            needsExifToolInstallation: needsExifToolInstallation
        )
    }

    private static func detectSonyModel(fromSidecars sidecars: [URL]) -> String? {
        for sidecar in sidecars {
            guard let handle = try? FileHandle(forReadingFrom: sidecar) else { continue }
            defer { try? handle.close() }

            let data = (try? handle.read(upToCount: 262_144)) ?? Data()
            guard let metadata = String(data: data, encoding: .utf8) else { continue }
            if let model = explicitSonyModelValue(in: metadata) {
                return model
            }
        }
        return nil
    }

    private static func detectSonyModel(from fileURL: URL?) -> String? {
        guard let fileURL, let exifToolPath else { return nil }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: exifToolPath)
        task.arguments = [
            "-fast2", "-s",
            "-Make", "-Model", "-CameraModelName", "-XMP:Model", "-QuickTime:Model",
            "--", fileURL.path
        ]
        let output = Pipe()
        task.standardOutput = output
        task.standardError = Pipe()

        let completion = DispatchSemaphore(value: 0)
        task.terminationHandler = { _ in completion.signal() }
        do {
            try task.run()
        } catch {
            return nil
        }

        guard completion.wait(timeout: .now() + 2) == .success else {
            task.terminate()
            _ = completion.wait(timeout: .now() + 0.25)
            return nil
        }
        guard task.terminationStatus == 0,
              let metadata = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
            return nil
        }

        return explicitSonyModelValue(in: metadata)
    }

    private static func explicitSonyModelValue(in metadata: String) -> String? {
        if let identifier = sonyModelIdentifier(in: metadata) {
            return identifier
        }

        let xmlPattern = "<(?:[A-Z0-9_-]+:)?(?:CAMERAMODEL(?:NAME)?|DEVICEMODEL(?:NAME)?|MODEL(?:NAME)?)\\b[^>]*>\\s*([^<]{1,80})"
        if let expression = try? NSRegularExpression(pattern: xmlPattern, options: [.caseInsensitive]),
           let match = expression.firstMatch(
               in: metadata,
               options: [],
               range: NSRange(location: 0, length: metadata.utf16.count)
           ),
           let range = Range(match.range(at: 1), in: metadata),
           let model = readableSonyModel(String(metadata[range])) {
            return model
        }

        for line in metadata.components(separatedBy: .newlines) {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  parts[0].uppercased().contains("MODEL") else { continue }

            if let model = readableSonyModel(String(parts[1])) {
                return model
            }
        }
        return nil
    }

    private static func readableSonyModel(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 80,
              trimmed.range(of: "^[A-Za-z0-9][A-Za-z0-9 ._-]*$", options: .regularExpression) != nil else {
            return nil
        }
        return sonyModelIdentifier(in: trimmed) ?? trimmed
    }

    private static func sonyModelIdentifier(in metadata: String) -> String? {
        let normalized = metadata.uppercased()
        let pattern = "(?<![A-Z0-9-])(?:ILME|ILCE|ILCA|PXW|HXR|FDR|HDR|DSC|NEX|SLT|MPC)-[A-Z0-9]+(?:-[A-Z0-9]+)*(?![A-Z0-9-])"
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: normalized,
                options: [],
                range: NSRange(location: 0, length: normalized.utf16.count)
              ),
              let range = Range(match.range, in: normalized) else {
            return nil
        }

        let identifier = String(normalized[range])
        if identifier.hasPrefix("ILME-") {
            return String(identifier.dropFirst("ILME-".count))
        }
        if identifier.hasPrefix("ILCE-") || identifier.hasPrefix("ILCA-") {
            return "A" + String(identifier.dropFirst(5))
        }
        return identifier
    }
    
    public static func isARRIRAWFile(fileURL: URL) -> Bool {
        let ext = fileURL.pathExtension.lowercased()
        if ext == "ari" || ext == "arx" { return true }
        guard ext == "mxf" else { return false }
        
        // Fast binary MXF header inspection (Read first 16KB of MXF KLV metadata)
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return false }
        defer { try? handle.close() }
        
        let headerData = (try? handle.read(upToCount: 16384)) ?? Data()
        guard !headerData.isEmpty else { return false }
        
        // Convert header bytes to ASCII string for Codec Universal Labels / FourCC / metadata tags
        if let ascii = String(bytes: headerData, encoding: .ascii) {
            let lower = ascii.lowercased()
            // Check for explicit ProRes tags in MXF Header
            if lower.contains("prores") || lower.contains("ap4h") || lower.contains("ap4x") || lower.contains("apcn") || lower.contains("apch") {
                return false
            }
            // Check for explicit ARRIRAW tags in MXF Header Partition
            if lower.contains("arriraw") || lower.contains("arri raw") || lower.contains("arri_mxf") {
                return true
            }
        }
        
        // Fallback: Check if file follows ARRI Cinema Clip Naming convention (e.g. A001_C001_...)
        let name = fileURL.lastPathComponent
        let isArriClipPattern = name.range(of: "^[A-Z]\\d{3}_C\\d{3}_", options: .regularExpression) != nil
        return isArriClipPattern
    }
}

public class HDECalculator {
    public static func findCodexCLI() -> String? {
        let possiblePaths = [
            "/usr/local/bin/codex-hde",
            "/opt/codex/bin/codex-hde",
            "/Applications/Codex Device Manager.app/Contents/Resources/bin/codex-hde",
            "/usr/bin/codex-hde"
        ]
        let fm = FileManager.default
        for path in possiblePaths {
            if fm.isExecutableFile(atPath: path) { return path }
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["codex-hde"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !out.isEmpty, fm.isExecutableFile(atPath: out) {
            return out
        }
        return nil
    }
    
    public static func calculateHDE(volumePath: String, hasAri: Bool, deviceType: String, arriRawBytes: Int64 = 0, nonRawBytes: Int64 = 0) -> HDEResult? {
        var stat = statfs()
        var usedBytes: Int64 = 0
        if statfs(volumePath, &stat) == 0 {
            let total = Int64(stat.f_blocks) * Int64(stat.f_bsize)
            let free = Int64(stat.f_bavail) * Int64(stat.f_bsize)
            usedBytes = max(0, total - free)
        }
        
        let isHDESupported = hasAri || deviceType.contains("ARRI") || deviceType.contains("Cinema")
        if !isHDESupported || usedBytes == 0 { return nil }
        
        let cliPath = findCodexCLI()
        let isCLIAvailable = cliPath != nil
        
        // If arriRawBytes is scanned, calculate HDE specifically on RAW content
        let rawBytesToCompress = arriRawBytes > 0 ? arriRawBytes : (hasAri ? usedBytes : 0)
        let uncompressibleBytes = arriRawBytes > 0 ? nonRawBytes : 0
        
        // If card only contains ProRes / Non-RAW files, HDE does not apply
        if rawBytesToCompress == 0 {
            return nil
        }
        
        // HDE lossless ARRIRAW algorithm ratio (~40% space savings -> 60% of original size)
        let rawAfterHDE = Int64(Double(rawBytesToCompress) * 0.60)
        let estimatedBytes = rawAfterHDE + uncompressibleBytes
        let savedBytes = max(0, usedBytes - estimatedBytes)
        
        let ratioPercent = usedBytes > 0 ? Int(Double(savedBytes) / Double(usedBytes) * 100) : 40
        
        return HDEResult(
            isHDESupported: true,
            isCLIAvailable: isCLIAvailable,
            cliPath: cliPath,
            estimatedBytes: estimatedBytes,
            savedBytes: savedBytes,
            compressionRatioPercent: max(0, ratioPercent)
        )
    }
}

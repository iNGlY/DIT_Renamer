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
            || fm.fileExists(atPath: url.appendingPathComponent("PRIVATE/XDROOT").path)
            || fm.fileExists(atPath: url.appendingPathComponent("XDROOT").path)
        
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
        var arriALESidecars: [URL] = []
        var sidecarURLs: [URL] = []
        var directoryNames = Set<String>()
        var mediaExtensions = Set<String>()
        var representativeMediaURLs: [String: URL] = [:]
        var videoFileSizes: [String: Int64] = [:]
        var detectedARRIRAWNames = Set<String>()
        
        var earliestDate: Date? = nil
        var latestDate: Date? = nil
        
        let videoExts: Set<String> = ["mov", "mp4", "mxf", "ari", "crm", "rdc", "r3d", "braw", "nev"]
        let photoExts: Set<String> = ["jpg", "jpeg", "png", "arw", "cr3", "cr2", "nef", "dng", "raf", "orf", "rw2", "tif", "tiff"]
        
        var arriRawBytes: Int64 = 0
        var nonRawBytes: Int64 = 0
        var scanTruncated = false
        
        for case let fileURL as URL in enumerator {
            if Task.isCancelled {
                scanTruncated = true
                break
            }
            let name = fileURL.lastPathComponent
            let ext = fileURL.pathExtension.lowercased()
            let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            
            if isDir {
                directoryNames.insert(name.lowercased())
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
                if !ext.isEmpty { mediaExtensions.insert(ext) }
                if (videoExts.contains(ext) || photoExts.contains(ext)),
                   representativeMediaURLs[ext] == nil {
                    representativeMediaURLs[ext] = fileURL
                }
                if name.lowercased().hasPrefix("dji_") {
                    directoryNames.insert("dji")
                }

                if sidecarURLs.count < 32,
                   ["ale", "xml", "xmp", "rmd", "srt", "sidecar"].contains(ext),
                   fSize >= 0,
                   fSize <= 4_194_304 {
                    sidecarURLs.append(fileURL)
                }

                if ext == "ale",
                   arriALESidecars.count < 8,
                   fSize > 0,
                   fSize <= 4_194_304 {
                    arriALESidecars.append(fileURL)
                }
                
                if videoExts.contains(ext) {
                    videoClips.append(name)
                    videoFileSizes[name] = fSize
                    if metadataCandidateURL == nil || (ext == "mp4" && metadataCandidateURL?.pathExtension.lowercased() != "mp4") {
                        metadataCandidateURL = fileURL
                    }
                    if ext == "braw" { hasBraw = true }
                    if ext == "nev" { hasNev = true }
                    if ext == "r3d" { hasR3d = true }
                    
                    // Inspect the MXF header to distinguish ARRIRAW from ProRes.
                    let isRaw = MediaScanner.isARRIRAWFile(fileURL: fileURL)
                    if isRaw {
                        hasAri = true
                        arriRawBytes += fSize
                        detectedARRIRAWNames.insert(name)
                    } else {
                        nonRawBytes += fSize
                    }
                } else if photoExts.contains(ext) {
                    photoClips.append(name)
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

        var cameraMetadataEvidence = CameraSidecarParsers.bestEvidence(
            sidecarURLs: sidecarURLs,
            directoryNames: directoryNames,
            mediaExtensions: mediaExtensions
        )
        let hasDJISubtitle = sidecarURLs.contains {
            $0.pathExtension.caseInsensitiveCompare("srt") == .orderedSame
                && $0.lastPathComponent.lowercased().hasPrefix("dji_")
        }
        if cameraMetadataEvidence?.manufacturer?.caseInsensitiveCompare("DJI") == .orderedSame,
           hasDJISubtitle,
           mediaExtensions.contains("dng") {
            let cinemaDNG = photoClips.filter {
                ($0 as NSString).pathExtension.caseInsensitiveCompare("dng") == .orderedSame
            }
            videoClips.append(contentsOf: cinemaDNG)
            photoClips.removeAll {
                ($0 as NSString).pathExtension.caseInsensitiveCompare("dng") == .orderedSame
            }
        }

        videoClips.sort()
        photoClips.sort()
        let firstClip = videoClips.first
        let lastClip = videoClips.last
        let arriMetadata = detectARRIMetadata(fromALEs: arriALESidecars)
            ?? detectARRIMetadata(from: metadataCandidateURL)
        if let arriMetadata {
            hasAri = hasAri || arriMetadata.containsARRIRAW
            for sourceName in arriMetadata.arrirawSourceFiles {
                guard !detectedARRIRAWNames.contains(sourceName),
                      let size = videoFileSizes[sourceName] else { continue }
                detectedARRIRAWNames.insert(sourceName)
                arriRawBytes += size
                nonRawBytes = max(0, nonRawBytes - size)
            }
            if cameraMetadataEvidence?.manufacturer?.caseInsensitiveCompare("ARRI") != .orderedSame,
               let model = arriMetadata.cameraModel {
                cameraMetadataEvidence = CameraMetadataEvidence(
                    manufacturer: "ARRI",
                    exactModel: model,
                    productFamily: "ARRI ALEXA/AMIRA",
                    source: .containerMetadata,
                    confidence: .high,
                    isCameraNative: true,
                    sourceFileName: metadataCandidateURL?.lastPathComponent
                )
            }
        }
        let sonyEvidenceModel = cameraMetadataEvidence?.manufacturer?.caseInsensitiveCompare("Sony") == .orderedSame
            ? cameraMetadataEvidence?.exactModel.flatMap(readableSonyModel)
            : nil
        let sonyModelFromSidecars = sonyEvidenceModel
        let sonyModel = sonyModelFromSidecars
            ?? (hasSonyStructure && shouldInspectCameraMetadata
                ? detectSonyModel(from: metadataCandidateURL)
                : nil)
        if hasSonyStructure,
           let sonyModel,
           (cameraMetadataEvidence?.exactModel == nil
                || cameraMetadataEvidence?.manufacturer?.caseInsensitiveCompare("Sony") != .orderedSame) {
            cameraMetadataEvidence = CameraMetadataEvidence(
                manufacturer: "Sony",
                exactModel: sonyModel,
                productFamily: "Sony XAVC/XDCAM",
                source: sonyModelFromSidecars == nil ? .exifTool : .sonyNonRealTimeMeta,
                confidence: .high,
                isCameraNative: true,
                sourceFileName: sonyModelFromSidecars == nil
                    ? metadataCandidateURL?.lastPathComponent
                    : cameraMetadataEvidence?.sourceFileName
            )
        }

        let containerCandidate = representativeMediaURL(
            for: cameraMetadataEvidence?.manufacturer,
            candidates: representativeMediaURLs
        )
        let supportsContainerFallback = supportsExifToolContainerFallback(
            manufacturer: cameraMetadataEvidence?.manufacturer
        )
        if shouldInspectCameraMetadata,
           supportsContainerFallback,
           cameraMetadataEvidence?.exactModel == nil,
           let manufacturer = cameraMetadataEvidence?.manufacturer,
           let containerCandidate,
           let detected = detectCameraMetadata(
               from: containerCandidate,
               expectedManufacturer: manufacturer,
               productFamily: cameraMetadataEvidence?.productFamily
           ) {
            cameraMetadataEvidence = detected
        }
        let needsExifToolInstallation = shouldInspectCameraMetadata
            && exifToolPath == nil
            && ((hasSonyStructure && sonyModelFromSidecars == nil && metadataCandidateURL != nil)
                || (supportsContainerFallback
                    && cameraMetadataEvidence?.exactModel == nil
                    && containerCandidate != nil))
        
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
                isHighConfidence: false, isUnconfiguredCamera: false, isEmptyCard: false, isPhotoOnly: true, photoCount: photoClips.count,
                cameraMetadataEvidence: cameraMetadataEvidence
            )
        }
        
        // 3. Check for DJI 4D Specific Folder Match
        if cameraMetadataEvidence?.manufacturer?.caseInsensitiveCompare("DJI") == .orderedSame,
           let djiFolder = djiFolders.first {
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
                    deviceType: cameraDeviceType(for: cameraMetadataEvidence, fallback: "DJI Camera Media"),
                    clipCount: videoClips.count,
                    totalFileCount: totalFileCount,
                    firstClipName: firstClip,
                    lastClipName: lastClip,
                    isHighConfidence: false,
                    isScanComplete: !scanTruncated,
                    cameraMetadataEvidence: cameraMetadataEvidence
                )
            }
        }
        
        // 4. Check clip files & camera models
        if let first = firstClip {
            let range = NSRange(location: 0, length: first.utf16.count)

            // A. ARRI camera media. ALE is the preferred model/codec source;
            // bounded MXF header metadata and a verified Codex HDE pair are fallbacks.
            let codexHDEDetected = HDECalculator.hasVerifiedCodexHDEContext(volumePath: volumePath)
            if arriMetadata != nil || hasAri || codexHDEDetected {
                let identity = arriClipIdentity(from: first)
                let arriModel = cameraMetadataEvidence?.manufacturer?.caseInsensitiveCompare("ARRI") == .orderedSame
                    ? cameraMetadataEvidence?.exactModel
                    : arriMetadata?.cameraModel
                let deviceType = arriModel.map {
                    $0.uppercased().hasPrefix("ARRI ") ? $0 : "ARRI \($0)"
                } ?? (codexHDEDetected ? "ARRI Codex Camera Media" : "ARRI Camera")
                let isUnformatted = dateSpanDays >= 2
                let hde = HDECalculator.calculateHDE(
                    volumePath: volumePath,
                    hasAri: hasAri,
                    deviceType: deviceType,
                    arriRawBytes: arriRawBytes,
                    nonRawBytes: nonRawBytes
                )

                return ScanResult(
                    suggestedName: identity?.reelName,
                    cameraLetter: identity?.cameraLetter,
                    rollNumber: identity?.rollNumber,
                    suffix: identity?.suffix,
                    deviceType: deviceType,
                    clipCount: videoClips.count,
                    totalFileCount: totalFileCount,
                    firstClipName: firstClip,
                    lastClipName: lastClip,
                    isHighConfidence: arriModel != nil && !scanTruncated,
                    isUnconfiguredCamera: false,
                    isEmptyCard: false,
                    isPhotoOnly: false,
                    photoCount: 0,
                    isUnformattedCard: isUnformatted,
                    dateSpanDays: dateSpanDays,
                    earliestDateStr: earliestDateStr,
                    latestDateStr: latestDateStr,
                    hdeResult: hde,
                    isScanComplete: !scanTruncated,
                    cameraMetadataEvidence: cameraMetadataEvidence
                )
            }
            
            // B. DEFENSE: Check for Sony Default Unconfigured Clip Name (e.g., C0001.MP4, C0042.MOV)
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
                    needsExifToolInstallation: needsExifToolInstallation,
                    cameraMetadataEvidence: cameraMetadataEvidence
                )
            }
            
            // C. Observed Sony cinema-style pattern. Metadata is still required for the model.
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
                    needsExifToolInstallation: needsExifToolInstallation,
                    cameraMetadataEvidence: cameraMetadataEvidence
                )
            }
            
            // D. Nikon ZR / Z Cinema Pattern (e.g. A001_C018_0731IT.MOV / .R3D / .NEV)
            // Observed shape: camera ID, roll, clip number, date, and a short suffix.
            let nikonZrRegex = try? NSRegularExpression(pattern: "^([A-Z])(\\d{3})_C\\d{3}_(\\d{4})([A-Z0-9]{2})", options: [])
            if (hasNev || (hasR3d && !hasRdcFolder && !hasRdmFolder)),
               let match = nikonZrRegex?.firstMatch(in: first, options: [], range: range) {
                let camera = String(first[Range(match.range(at: 1), in: first)!])
                let roll = String(first[Range(match.range(at: 2), in: first)!])
                let suggested = "\(camera)\(roll)"
                
                let devName: String
                if hasNev {
                    devName = cameraDeviceType(for: cameraMetadataEvidence, fallback: "Nikon N-RAW")
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
                    earliestDateStr: earliestDateStr, latestDateStr: latestDateStr,
                    cameraMetadataEvidence: cameraMetadataEvidence
                )
            }
            
            // E. Native RED Digital Cinema (Contains .RDC or .RDM folders)
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
                    deviceType: cameraDeviceType(for: cameraMetadataEvidence, fallback: "RED Digital Cinema"),
                    clipCount: videoClips.count, totalFileCount: totalFileCount,
                    firstClipName: firstClip, lastClipName: lastClip,
                    // RDC/RDM proves a RED media structure, not the Camera ID or Reel.
                    isHighConfidence: false, isUnconfiguredCamera: false,
                    isEmptyCard: false, isPhotoOnly: false, photoCount: 0,
                    isUnformattedCard: isUnformatted, dateSpanDays: dateSpanDays,
                    earliestDateStr: earliestDateStr, latestDateStr: latestDateStr,
                    cameraMetadataEvidence: cameraMetadataEvidence
                )
            }
            
            // F. Generic cinema-style pattern. It is not a vendor or model proof.
            let standardCinemaRegex = try? NSRegularExpression(pattern: "^([A-Z])(\\d{3})_", options: [])
            if let match = standardCinemaRegex?.firstMatch(in: first, options: [], range: range) {
                let camera = String(first[Range(match.range(at: 1), in: first)!])
                let roll = String(first[Range(match.range(at: 2), in: first)!])
                let suggested = "\(camera)\(roll)"
                let isUnformatted = dateSpanDays >= 2
                
                let device = cameraDeviceType(
                    for: cameraMetadataEvidence,
                    fallback: hasBraw ? "Blackmagic RAW" : "Cinema Card"
                )
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
                    hdeResult: hde,
                    cameraMetadataEvidence: cameraMetadataEvidence
                )
            }
        }
        
        let isUnformatted = dateSpanDays >= 2
        let fallbackDevice = cameraDeviceType(
            for: cameraMetadataEvidence,
            fallback: hasBraw ? "Blackmagic RAW" : "Unrecognized Media"
        )
        let fallbackHde = HDECalculator.calculateHDE(volumePath: volumePath, hasAri: hasAri, deviceType: fallbackDevice, arriRawBytes: arriRawBytes, nonRawBytes: nonRawBytes)
        return ScanResult(
            suggestedName: nil, cameraLetter: nil, rollNumber: nil, suffix: nil,
            deviceType: fallbackDevice,
            clipCount: videoClips.count, totalFileCount: totalFileCount,
            firstClipName: firstClip, lastClipName: lastClip,
            isHighConfidence: false, isUnconfiguredCamera: false,
            isEmptyCard: false, isPhotoOnly: false, photoCount: 0,
            isUnformattedCard: isUnformatted, dateSpanDays: dateSpanDays,
            earliestDateStr: earliestDateStr, latestDateStr: latestDateStr,
            hdeResult: fallbackHde,
            isScanComplete: !scanTruncated,
            needsExifToolInstallation: needsExifToolInstallation,
            cameraMetadataEvidence: cameraMetadataEvidence
        )
    }

    private static func cameraDeviceType(
        for evidence: CameraMetadataEvidence?,
        fallback: String
    ) -> String {
        guard let evidence,
              let manufacturer = evidence.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
              !manufacturer.isEmpty else { return fallback }

        let exactModel = evidence.exactModel?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch manufacturer.lowercased() {
        case "arri":
            guard let exactModel, !exactModel.isEmpty else { return fallback }
            return exactModel.uppercased().hasPrefix("ARRI ") ? exactModel : "ARRI \(exactModel)"
        case "sony":
            guard let exactModel, let readable = readableSonyModel(exactModel) else { return "Sony Camera Media" }
            return readable.uppercased().hasPrefix("SONY ") ? readable : "Sony \(readable)"
        case "panasonic":
            guard let exactModel, !exactModel.isEmpty else { return "Panasonic P2 Camera Media" }
            return exactModel.uppercased().hasPrefix("PANASONIC ") ? exactModel : "Panasonic \(exactModel)"
        case "canon":
            guard let exactModel, !exactModel.isEmpty else { return "Canon XF Camera Media" }
            return exactModel.uppercased().hasPrefix("CANON ") ? exactModel : "Canon \(exactModel)"
        case "red":
            guard let exactModel, !exactModel.isEmpty else { return "RED Digital Cinema" }
            return exactModel.uppercased().hasPrefix("RED ") ? exactModel : "RED \(exactModel)"
        case "dji":
            guard let exactModel, !exactModel.isEmpty else { return "DJI Camera Media" }
            return exactModel.uppercased().hasPrefix("DJI ") ? exactModel : "DJI \(exactModel)"
        case "nikon":
            guard let exactModel, !exactModel.isEmpty else { return "Nikon N-RAW" }
            return exactModel.uppercased().hasPrefix("NIKON ") ? exactModel : "Nikon \(exactModel)"
        case "blackmagic design":
            guard let exactModel, !exactModel.isEmpty else { return "Blackmagic RAW" }
            return exactModel.uppercased().hasPrefix("BLACKMAGIC ") ? exactModel : "Blackmagic Design \(exactModel)"
        default:
            return evidence.displayName ?? fallback
        }
    }

    private struct ARRIMetadata {
        let cameraModel: String?
        let arrirawSourceFiles: Set<String>
        let containsARRIRAW: Bool
    }

    private struct ARRIClipIdentity {
        let cameraLetter: String
        let rollNumber: String
        let suffix: String?
        let reelName: String
    }

    private static func detectARRIMetadata(fromALEs sidecars: [URL]) -> ARRIMetadata? {
        var detectedModel: String?
        var rawSources = Set<String>()
        var containsARRIRAW = false
        var hasARRIEvidence = false

        for sidecar in sidecars {
            guard let handle = try? FileHandle(forReadingFrom: sidecar) else { continue }
            defer { try? handle.close() }
            let data = (try? handle.read(upToCount: 4_194_304)) ?? Data()
            guard !data.isEmpty else { continue }

            let lines = String(decoding: data, as: UTF8.self).components(separatedBy: .newlines)
            guard let columnMarker = lines.firstIndex(where: {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Column") == .orderedSame
            }),
            let headerIndex = lines[(columnMarker + 1)...].firstIndex(where: {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }),
            let dataMarker = lines[headerIndex...].firstIndex(where: {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Data") == .orderedSame
            }) else { continue }

            let headers = lines[headerIndex].components(separatedBy: "\t")
            let normalizedHeaders = headers.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            let manufacturerIndex = normalizedHeaders.firstIndex(of: "manufacturer")
            let modelIndex = normalizedHeaders.firstIndex(of: "camera_model")
            let originalVideoIndex = normalizedHeaders.firstIndex(of: "original_video")
            let sourceFileIndex = normalizedHeaders.firstIndex(of: "source file")

            for line in lines.dropFirst(dataMarker + 1) {
                guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let values = line.components(separatedBy: "\t")
                func value(at index: Int?) -> String? {
                    guard let index, values.indices.contains(index) else { return nil }
                    let value = values[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? nil : value
                }

                let manufacturer = value(at: manufacturerIndex)
                let model = value(at: modelIndex)
                let originalVideo = value(at: originalVideoIndex)
                if manufacturer?.range(of: "ARRI", options: .caseInsensitive) != nil
                    || model?.range(of: "ALEXA|AMIRA|ARRI", options: [.regularExpression, .caseInsensitive]) != nil {
                    hasARRIEvidence = true
                }
                if detectedModel == nil, let model {
                    detectedModel = normalizedARRICameraModel(model)
                }
                if originalVideo?.range(of: "ARRIRAW", options: .caseInsensitive) != nil {
                    containsARRIRAW = true
                    if let sourceFile = value(at: sourceFileIndex) {
                        rawSources.insert(URL(fileURLWithPath: sourceFile).lastPathComponent)
                    }
                }
            }
        }

        guard hasARRIEvidence || containsARRIRAW || detectedModel != nil else { return nil }
        return ARRIMetadata(
            cameraModel: detectedModel,
            arrirawSourceFiles: rawSources,
            containsARRIRAW: containsARRIRAW
        )
    }

    private static func detectARRIMetadata(from fileURL: URL?) -> ARRIMetadata? {
        guard let fileURL,
              fileURL.pathExtension.caseInsensitiveCompare("mxf") == .orderedSame,
              let handle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? handle.close() }

        let data = (try? handle.read(upToCount: 262_144)) ?? Data()
        guard !data.isEmpty else { return nil }
        let metadata = String(decoding: data, as: UTF8.self)
        let pattern = #"(?i)[\"']?cameraModel[\"']?\s*[:=]\s*[\"']([^\"'\r\n]{1,80})[\"']"#
        var cameraModel: String?
        if let expression = try? NSRegularExpression(pattern: pattern),
           let match = expression.firstMatch(
                in: metadata,
                options: [],
                range: NSRange(location: 0, length: metadata.utf16.count)
           ),
           let valueRange = Range(match.range(at: 1), in: metadata) {
            cameraModel = normalizedARRICameraModel(String(metadata[valueRange]))
        }

        let isRaw = isARRIRAWFile(fileURL: fileURL)
        guard cameraModel != nil || isRaw else { return nil }
        return ARRIMetadata(
            cameraModel: cameraModel,
            arrirawSourceFiles: isRaw ? Set([fileURL.lastPathComponent]) : Set<String>(),
            containsARRIRAW: isRaw
        )
    }

    private static func normalizedARRICameraModel(_ value: String) -> String? {
        var model = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty, model.count <= 80 else { return nil }
        if model.uppercased().hasPrefix("ARRI ") {
            model = String(model.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard model.range(of: "ALEXA|AMIRA", options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
        return model
    }

    private static func arriClipIdentity(from fileName: String) -> ARRIClipIdentity? {
        let modernPattern = #"^([A-Z])_(\d{4})C\d{3}_\d{6}_\d{6}_[aAhH]([A-Z0-9]+)\.mxf$"#
        if let expression = try? NSRegularExpression(pattern: modernPattern, options: [.caseInsensitive]),
           let match = expression.firstMatch(
                in: fileName,
                options: [],
                range: NSRange(location: 0, length: fileName.utf16.count)
           ),
           let cameraRange = Range(match.range(at: 1), in: fileName),
           let rollRange = Range(match.range(at: 2), in: fileName),
           let suffixRange = Range(match.range(at: 3), in: fileName) {
            let camera = String(fileName[cameraRange]).uppercased()
            let roll = String(fileName[rollRange])
            let suffixValue = String(fileName[suffixRange]).uppercased()
            return ARRIClipIdentity(
                cameraLetter: camera,
                rollNumber: roll,
                suffix: "_\(suffixValue)",
                reelName: "\(camera)_\(roll)_\(suffixValue)"
            )
        }
        return nil
    }

    public static func mediaFingerprint(volumePath: String) -> (firstClipName: String?, lastClipName: String?) {
        let url = URL(fileURLWithPath: volumePath)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return (nil, nil) }

        let videoExtensions: Set<String> = ["mov", "mp4", "mxf", "ari", "arx", "crm", "r3d", "braw", "nev"]
        var clipNames: [String] = []
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { return (nil, nil) }
            guard videoExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
            clipNames.append(fileURL.lastPathComponent)
            if clipNames.count > 5000 { return (nil, nil) }
        }
        clipNames.sort()
        return (clipNames.first, clipNames.last)
    }

    private static func detectSonyModel(from fileURL: URL?) -> String? {
        guard let fileURL,
              let data = exifToolJSONData(from: fileURL),
              let evidence = cameraMetadataEvidenceFromExifToolJSON(
                data,
                expectedManufacturer: "Sony",
                productFamily: "Sony XAVC/XDCAM",
                sourceFileName: fileURL.lastPathComponent
              ),
              let exactModel = evidence.exactModel else { return nil }
        return readableSonyModel(exactModel)
    }

    private static func detectCameraMetadata(
        from fileURL: URL,
        expectedManufacturer: String,
        productFamily: String?
    ) -> CameraMetadataEvidence? {
        guard let data = exifToolJSONData(from: fileURL) else { return nil }
        return cameraMetadataEvidenceFromExifToolJSON(
            data,
            expectedManufacturer: expectedManufacturer,
            productFamily: productFamily,
            sourceFileName: fileURL.lastPathComponent
        )
    }

    private static func exifToolJSONData(from fileURL: URL) -> Data? {
        guard let exifToolPath else { return nil }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: exifToolPath)
        task.arguments = [
            "-fast2", "-j", "-s",
            "-Make", "-Model", "-CameraModelName", "-DeviceManufacturer", "-DeviceModelName", "-CameraType",
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
        guard task.terminationStatus == 0 else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return data.isEmpty ? nil : data
    }

    static func cameraMetadataEvidenceFromExifToolJSON(
        _ data: Data,
        expectedManufacturer: String,
        productFamily: String?,
        sourceFileName: String
    ) -> CameraMetadataEvidence? {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let metadata = array.first else { return nil }

        func firstString(_ keys: [String]) -> String? {
            for key in keys {
                guard let raw = metadata[key] as? String else { continue }
                let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty, value.count <= 120 { return value }
            }
            return nil
        }

        let manufacturer = firstString(["Make", "DeviceManufacturer"])
        guard let model = firstString(["CameraModelName", "DeviceModelName", "CameraType", "Model"]),
              isExpectedManufacturer(
                expectedManufacturer,
                reportedManufacturer: manufacturer,
                model: model
              ),
              isSpecificCameraModel(model, expectedManufacturer: expectedManufacturer) else {
            return nil
        }
        return CameraMetadataEvidence(
            manufacturer: expectedManufacturer,
            exactModel: model,
            productFamily: productFamily,
            source: .exifTool,
            confidence: .medium,
            isCameraNative: true,
            sourceFileName: sourceFileName
        )
    }

    private static func isExpectedManufacturer(
        _ expectedManufacturer: String,
        reportedManufacturer: String?,
        model: String
    ) -> Bool {
        let aliases: [String]
        switch expectedManufacturer.lowercased() {
        case "blackmagic design": aliases = ["blackmagic", "blackmagicdesign"]
        default: aliases = [expectedManufacturer]
        }
        let normalizedMaker = normalizedMetadataToken(reportedManufacturer ?? "")
        let normalizedModel = normalizedMetadataToken(model)
        return aliases.map(normalizedMetadataToken).contains { alias in
            (!normalizedMaker.isEmpty && normalizedMaker.contains(alias))
                || normalizedModel.contains(alias)
        }
    }

    private static func isSpecificCameraModel(
        _ model: String,
        expectedManufacturer: String
    ) -> Bool {
        let normalizedModel = normalizedMetadataToken(model)
        let genericValues: Set<String> = [
            "camera", "digitalcamera", "cinemacamera", "unknown", "none",
            normalizedMetadataToken(expectedManufacturer)
        ]
        return !genericValues.contains(normalizedModel) && normalizedModel.count >= 3
    }

    private static func normalizedMetadataToken(_ value: String) -> String {
        value.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
            .lowercased()
    }

    private static func supportsExifToolContainerFallback(manufacturer: String?) -> Bool {
        guard let manufacturer else { return false }
        return ["Canon", "RED", "DJI", "Nikon", "Blackmagic Design"].contains {
            manufacturer.caseInsensitiveCompare($0) == .orderedSame
        }
    }

    private static func representativeMediaURL(
        for manufacturer: String?,
        candidates: [String: URL]
    ) -> URL? {
        guard let manufacturer else { return nil }
        let preferredExtensions: [String]
        switch manufacturer.lowercased() {
        case "canon": preferredExtensions = ["mxf", "crm", "mp4", "mov"]
        case "red": preferredExtensions = ["r3d"]
        case "dji": preferredExtensions = ["dng", "mov", "mp4", "mxf"]
        case "nikon": preferredExtensions = ["nev", "mov", "mp4"]
        case "blackmagic design": preferredExtensions = ["braw"]
        default: return nil
        }
        return preferredExtensions.lazy.compactMap { candidates[$0] }.first
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
        
        // Lossy UTF-8 decoding preserves embedded ASCII metadata even when the
        // surrounding MXF KLV bytes are not valid ASCII/UTF-8.
        let headerText = String(decoding: headerData, as: UTF8.self)
        let lower = headerText.lowercased()
        // Check for explicit ProRes tags in MXF Header.
        if lower.contains("prores") || lower.contains("ap4h") || lower.contains("ap4x") || lower.contains("apcn") || lower.contains("apch") {
            return false
        }
        // Check for explicit ARRIRAW tags in MXF Header Partition.
        if lower.contains("arriraw") || lower.contains("arri raw") || lower.contains("arri_mxf") {
            return true
        }
        // Current ARRI MXF stores cameraModel near the beginning of the file.
        // The `_a...mxf` suffix distinguishes the ARRIRAW source from the
        // `_h...mxf` HDE virtual companion presented by Codex Device Manager.
        let name = fileURL.lastPathComponent
        let isARRIRAWSourceName = name.range(
            of: #"_a[A-Z0-9]+\.mxf$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        if isARRIRAWSourceName,
           lower.contains("cameramodel"),
           (lower.contains("arri alexa") || lower.contains("amira")) {
            return true
        }
        
        // Fallback: look for an ARRI-style clip name as an additional hint.
        let isArriClipPattern = name.range(of: "^[A-Z]\\d{3}_C\\d{3}_", options: .regularExpression) != nil
        return isArriClipPattern || isARRIRAWSourceName
    }
}

public class HDECalculator {
    private struct CodexHDEContext {
        let sourcePath: String
        let companionPath: String
        let isCompanionSelection: Bool
    }

    private struct MediaByteBreakdown {
        let rawBytes: Int64
        let nonRawBytes: Int64
    }

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
    
    public static func hasVerifiedCodexHDEContext(volumePath: String) -> Bool {
        codexHDEContext(for: volumePath) != nil
    }

    public static func calculateHDE(volumePath: String, hasAri: Bool, deviceType: String, arriRawBytes: Int64 = 0, nonRawBytes: Int64 = 0) -> HDEResult? {
        let hdeContext = codexHDEContext(for: volumePath)
        var resolvedRawBytes = max(0, arriRawBytes)
        var resolvedNonRawBytes = max(0, nonRawBytes)

        // X2XFUSE reports HDE virtual MXF files as zero bytes. When the user
        // selects that mount, derive the estimate from its paired UDF source.
        if resolvedRawBytes == 0,
           let hdeContext,
           hdeContext.isCompanionSelection,
           let paired = mediaByteBreakdown(at: hdeContext.sourcePath) {
            resolvedRawBytes = paired.rawBytes
            resolvedNonRawBytes = paired.nonRawBytes
        }

        let sourceBytes = resolvedRawBytes + resolvedNonRawBytes
        let isHDESupported = hasAri || resolvedRawBytes > 0 || deviceType.contains("ARRI") || hdeContext != nil
        guard isHDESupported, resolvedRawBytes > 0, sourceBytes > 0 else { return nil }
        
        let cliPath = findCodexCLI()
        let isCLIAvailable = cliPath != nil

        // ARRI describes HDE as reducing ARRIRAW by roughly 40% or more.
        // Use 60% of original RAW bytes as a conservative reference estimate.
        let rawAfterHDE = Int64(Double(resolvedRawBytes) * 0.60)
        let estimatedBytes = rawAfterHDE + resolvedNonRawBytes
        let savedBytes = max(0, resolvedRawBytes - rawAfterHDE)
        let ratioPercent = Int(Double(savedBytes) / Double(sourceBytes) * 100)
        
        return HDEResult(
            isHDESupported: true,
            isCLIAvailable: isCLIAvailable,
            cliPath: cliPath,
            sourceBytes: sourceBytes,
            estimatedBytes: estimatedBytes,
            savedBytes: savedBytes,
            compressionRatioPercent: max(0, ratioPercent),
            isHDEVolumeDetected: hdeContext != nil
        )
    }

    private static func codexHDEContext(for volumePath: String) -> CodexHDEContext? {
        let fm = FileManager.default
        let normalized = URL(fileURLWithPath: volumePath).standardizedFileURL.path
        let sourcePath: String
        let companionPath: String
        let isCompanionSelection: Bool

        if normalized.lowercased().hasSuffix("_hde") {
            sourcePath = String(normalized.dropLast(4))
            companionPath = normalized
            isCompanionSelection = true
        } else {
            sourcePath = normalized
            companionPath = normalized + "_hde"
            isCompanionSelection = false
        }

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: sourcePath, isDirectory: &isDirectory), isDirectory.boolValue,
              fm.fileExists(atPath: companionPath, isDirectory: &isDirectory), isDirectory.boolValue,
              fm.fileExists(atPath: URL(fileURLWithPath: companionPath).appendingPathComponent(".codexvfs").path) else {
            return nil
        }
        return CodexHDEContext(
            sourcePath: sourcePath,
            companionPath: companionPath,
            isCompanionSelection: isCompanionSelection
        )
    }

    private static func mediaByteBreakdown(at volumePath: String) -> MediaByteBreakdown? {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: volumePath)
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let videoExtensions: Set<String> = ["mxf", "ari", "arx", "mov"]
        var rawBytes: Int64 = 0
        var nonRawBytes: Int64 = 0
        var fileCount = 0
        for case let fileURL as URL in enumerator {
            guard videoExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
            let size = Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            if MediaScanner.isARRIRAWFile(fileURL: fileURL) {
                rawBytes += size
            } else {
                nonRawBytes += size
            }
            fileCount += 1
            if fileCount > 5000 { return nil }
        }
        guard rawBytes > 0 else { return nil }
        return MediaByteBreakdown(rawBytes: rawBytes, nonRawBytes: nonRawBytes)
    }
}

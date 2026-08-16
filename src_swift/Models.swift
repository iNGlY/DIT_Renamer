import Foundation

public enum CameraMetadataConfidence: String, Codable, Hashable {
    case low
    case medium
    case high

    public var labels: (zh: String, en: String) {
        switch self {
        case .low: return ("低", "Low")
        case .medium: return ("中", "Medium")
        case .high: return ("高", "High")
        }
    }
}

public enum CameraMetadataSource: String, Codable, Hashable {
    case arriALE = "arri-ale"
    case sonyNonRealTimeMeta = "sony-non-real-time-meta"
    case panasonicP2XML = "panasonic-p2-xml"
    case explicitSidecarField = "explicit-sidecar-field"
    case workflowSidecar = "workflow-sidecar"
    case directorySignature = "directory-signature"
    case containerMetadata = "container-metadata"
    case exifTool = "exiftool"

    public var labels: (zh: String, en: String) {
        switch self {
        case .arriALE: return ("ARRI ALE", "ARRI ALE")
        case .sonyNonRealTimeMeta: return ("Sony XML", "Sony XML")
        case .panasonicP2XML: return ("Panasonic P2 XML", "Panasonic P2 XML")
        case .explicitSidecarField: return ("明确的 Sidecar 字段", "Explicit sidecar field")
        case .workflowSidecar: return ("工作流 Sidecar", "Workflow sidecar")
        case .directorySignature: return ("卡目录结构", "Card directory signature")
        case .containerMetadata: return ("有限媒体头部", "Bounded media header")
        case .exifTool: return ("ExifTool", "ExifTool")
        }
    }
}

public struct CameraMetadataEvidence: Codable, Hashable {
    public let manufacturer: String?
    public let exactModel: String?
    public let productFamily: String?
    public let source: CameraMetadataSource
    public let confidence: CameraMetadataConfidence
    public let isCameraNative: Bool
    public let sourceFileName: String?
    public let attributes: [String: String]

    public init(
        manufacturer: String?,
        exactModel: String?,
        productFamily: String?,
        source: CameraMetadataSource,
        confidence: CameraMetadataConfidence,
        isCameraNative: Bool,
        sourceFileName: String? = nil,
        attributes: [String: String] = [:]
    ) {
        self.manufacturer = manufacturer
        self.exactModel = exactModel
        self.productFamily = productFamily
        self.source = source
        self.confidence = confidence
        self.isCameraNative = isCameraNative
        self.sourceFileName = sourceFileName
        self.attributes = attributes
    }

    public var displayName: String? {
        if let exactModel, !exactModel.isEmpty {
            if let manufacturer,
               !exactModel.uppercased().hasPrefix(manufacturer.uppercased()) {
                return "\(manufacturer) \(exactModel)"
            }
            return exactModel
        }
        if let productFamily, !productFamily.isEmpty { return productFamily }
        return manufacturer
    }
}

public enum MountedVolumeAccessLevel: String, Hashable {
    case renameCapable
    case inspectionOnly
    case codexCompanionReadOnly
}

public struct MountedVolume: Identifiable, Hashable {
    // BSD node keeps simultaneously mounted cards distinct even when cloned
    // FAT/exFAT media exposes the same volume UUID.
    public var id: String { mountSessionID ?? "\(volumeUUID ?? "NO-UUID")|\(bsdNode)" }
    public let name: String
    public let originalName: String
    public let path: String
    public let bsdNode: String
    public let volumeUUID: String?
    public let mediaUUID: String?
    public let mountSessionID: String?
    public let isRemovable: Bool
    public let isInternal: Bool
    public let freeBytes: Int64
    public let totalBytes: Int64
    public let isGenericName: Bool
    public let fileSystem: String
    public let accessLevel: MountedVolumeAccessLevel
    public let isReadOnly: Bool

    public init(
        name: String,
        originalName: String,
        path: String,
        bsdNode: String,
        volumeUUID: String?,
        mediaUUID: String?,
        mountSessionID: String? = nil,
        isRemovable: Bool,
        isInternal: Bool,
        freeBytes: Int64,
        totalBytes: Int64,
        isGenericName: Bool,
        fileSystem: String,
        accessLevel: MountedVolumeAccessLevel? = nil,
        isReadOnly: Bool = false
    ) {
        self.name = name
        self.originalName = originalName
        self.path = path
        self.bsdNode = bsdNode
        self.volumeUUID = volumeUUID
        self.mediaUUID = mediaUUID
        self.mountSessionID = mountSessionID
        self.isRemovable = isRemovable
        self.isInternal = isInternal
        self.freeBytes = freeBytes
        self.totalBytes = totalBytes
        self.isGenericName = isGenericName
        self.fileSystem = fileSystem
        self.accessLevel = accessLevel ?? ((volumeUUID?.isEmpty == false) ? .renameCapable : .inspectionOnly)
        self.isReadOnly = isReadOnly
    }

    public var canAttemptManualRename: Bool {
        !isReadOnly && accessLevel != .codexCompanionReadOnly
    }

    public var canAutomaticallyRename: Bool {
        canAttemptManualRename && accessLevel == .renameCapable && volumeUUID?.isEmpty == false
    }

    public var isCodexCompanion: Bool {
        accessLevel == .codexCompanionReadOnly
    }
    
    public var usedBytes: Int64 { max(0, totalBytes - freeBytes) }
    
    public var isUniqueCameraName: Bool {
        if isGenericName { return false }
        let regex = try? NSRegularExpression(pattern: "^[A-Z]\\d{2,4}")
        let range = NSRange(location: 0, length: name.utf16.count)
        return regex?.firstMatch(in: name, options: [], range: range) != nil
    }
    
    public var freeGBFormatted: String {
        let gb = Double(freeBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
    
    public var totalGBFormatted: String {
        let gb = Double(totalBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
    
    public var usedGBFormatted: String {
        let gb = Double(usedBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
    
    public var deviceTreeString: String {
        return "/dev/\(bsdNode) -> \(path)"
    }
    
    public static let genericNames: Set<String> = [
        "UNTITLED", "DJI", "NO NAME", "EOS_DIGITAL", "SONY", "SONY_CARD",
        "CANON", "NIKON", "SD", "CFX", "CFEXPRESS", "PROSSD", "DJI_PROSSD",
        "SND", "AUDIO", "RECORD", "NOCNAME"
    ]
    
    public static let defaultSystemIgnores: Set<String> = [
        "MACINTOSH HD", "MACINTOSH HD - DATA", "SYSTEM", "DATA",
        "PREBOOT", "RECOVERY", "VM", "UPDATE", "TIME MACHINE",
        "EFI", "BOOTCAMP", "VMWARE", "PARALLELS", "CONTAINER"
    ]
}

public struct HDEResult: Hashable {
    public let isHDESupported: Bool
    public let isCLIAvailable: Bool
    public let cliPath: String?
    public let sourceBytes: Int64
    public let estimatedBytes: Int64
    public let savedBytes: Int64
    public let compressionRatioPercent: Int
    public let isHDEVolumeDetected: Bool

    public var sourceGBFormatted: String {
        let gb = Double(sourceBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
    
    public var estimatedGBFormatted: String {
        let gb = Double(estimatedBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
    
    public var savedGBFormatted: String {
        let gb = Double(savedBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
    
    public init(
        isHDESupported: Bool,
        isCLIAvailable: Bool,
        cliPath: String?,
        sourceBytes: Int64? = nil,
        estimatedBytes: Int64,
        savedBytes: Int64,
        compressionRatioPercent: Int = 40,
        isHDEVolumeDetected: Bool = false
    ) {
        self.isHDESupported = isHDESupported
        self.isCLIAvailable = isCLIAvailable
        self.cliPath = cliPath
        self.sourceBytes = sourceBytes ?? max(0, estimatedBytes + savedBytes)
        self.estimatedBytes = estimatedBytes
        self.savedBytes = savedBytes
        self.compressionRatioPercent = compressionRatioPercent
        self.isHDEVolumeDetected = isHDEVolumeDetected
    }
}

public struct ScanResult {
    public let suggestedName: String?
    public let cameraLetter: String?
    public let rollNumber: String?
    public let suffix: String?
    public let deviceType: String
    public let clipCount: Int
    public let totalFileCount: Int
    public let firstClipName: String?
    public let lastClipName: String?
    public let isHighConfidence: Bool
    public let isUnconfiguredCamera: Bool
    public let isEmptyCard: Bool
    public let isPhotoOnly: Bool
    public let photoCount: Int
    public let isUnformattedCard: Bool
    public let dateSpanDays: Int
    public let earliestDateStr: String?
    public let latestDateStr: String?
    public let hdeResult: HDEResult?
    public let isScanComplete: Bool
    public let needsExifToolInstallation: Bool
    public let cameraMetadataEvidence: CameraMetadataEvidence?
    
    public init(suggestedName: String?,
                cameraLetter: String?,
                rollNumber: String?,
                suffix: String?,
                deviceType: String,
                clipCount: Int,
                totalFileCount: Int,
                firstClipName: String?,
                lastClipName: String?,
                isHighConfidence: Bool,
                isUnconfiguredCamera: Bool = false,
                isEmptyCard: Bool = false,
                isPhotoOnly: Bool = false,
                photoCount: Int = 0,
                isUnformattedCard: Bool = false,
                dateSpanDays: Int = 0,
                earliestDateStr: String? = nil,
                latestDateStr: String? = nil,
                hdeResult: HDEResult? = nil,
                isScanComplete: Bool = true,
                needsExifToolInstallation: Bool = false,
                cameraMetadataEvidence: CameraMetadataEvidence? = nil) {
        self.suggestedName = suggestedName
        self.cameraLetter = cameraLetter
        self.rollNumber = rollNumber
        self.suffix = suffix
        self.deviceType = deviceType
        self.clipCount = clipCount
        self.totalFileCount = totalFileCount
        self.firstClipName = firstClipName
        self.lastClipName = lastClipName
        self.isHighConfidence = isHighConfidence
        self.isUnconfiguredCamera = isUnconfiguredCamera
        self.isEmptyCard = isEmptyCard
        self.isPhotoOnly = isPhotoOnly
        self.photoCount = photoCount
        self.isUnformattedCard = isUnformattedCard
        self.dateSpanDays = dateSpanDays
        self.earliestDateStr = earliestDateStr
        self.latestDateStr = latestDateStr
        self.hdeResult = hdeResult
        self.isScanComplete = isScanComplete
        self.needsExifToolInstallation = needsExifToolInstallation
        self.cameraMetadataEvidence = cameraMetadataEvidence
    }
}

public enum AutomaticRenameReviewReason: Equatable {
    case lowConfidence
    case standardizedVolumeName
}

public enum AutomaticRenameReviewPolicy {
    public static func reason(
        isAutoRenameEnabled: Bool,
        canAutomaticallyRename: Bool,
        isGenericVolumeName: Bool,
        isHighConfidenceScan: Bool
    ) -> AutomaticRenameReviewReason? {
        guard isAutoRenameEnabled, canAutomaticallyRename else { return nil }
        if !isHighConfidenceScan { return .lowConfidence }
        if !isGenericVolumeName { return .standardizedVolumeName }
        return nil
    }
}

public struct RenameHistoryItem: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public let originalName: String
    public let newName: String
    public let firstClipName: String?
    public let lastClipName: String?
    public let clipCount: Int
    public let totalFileCount: Int
    public let usedSpace: String
    public let deviceType: String
    public let timestamp: Date
    public let dateDayString: String
    public var isUnformatted: Bool? = false
    public var isEmptyCard: Bool? = false
    public var requestedName: String? = nil
    public var reuseCount: Int? = nil
    public var duplicateIndex: Int? = nil
    public var volumeUUID: String? = nil
    public var mediaUUID: String? = nil
    public var bsdNode: String? = nil
    public var mountedPath: String? = nil
    public var fileSystem: String? = nil
    public var isHighConfidence: Bool? = nil
    public var isPhotoOnly: Bool? = nil
    public var isUnconfiguredCamera: Bool? = nil
    public var cameraMetadataEvidence: CameraMetadataEvidence? = nil
    
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    public init(id: UUID = UUID(),
                originalName: String,
                newName: String,
                firstClipName: String?,
                lastClipName: String?,
                clipCount: Int,
                totalFileCount: Int,
                usedSpace: String,
                deviceType: String,
                timestamp: Date,
                dateDayString: String,
                isUnformatted: Bool? = false,
                isEmptyCard: Bool? = false,
                requestedName: String? = nil,
                reuseCount: Int? = nil,
                duplicateIndex: Int? = nil,
                volumeUUID: String? = nil,
                mediaUUID: String? = nil,
                bsdNode: String? = nil,
                mountedPath: String? = nil,
                fileSystem: String? = nil,
                isHighConfidence: Bool? = nil,
                isPhotoOnly: Bool? = nil,
                isUnconfiguredCamera: Bool? = nil,
                cameraMetadataEvidence: CameraMetadataEvidence? = nil) {
        self.id = id
        self.originalName = originalName
        self.newName = newName
        self.firstClipName = firstClipName
        self.lastClipName = lastClipName
        self.clipCount = clipCount
        self.totalFileCount = totalFileCount
        self.usedSpace = usedSpace
        self.deviceType = deviceType
        self.timestamp = timestamp
        self.dateDayString = dateDayString
        self.isUnformatted = isUnformatted
        self.isEmptyCard = isEmptyCard
        self.requestedName = requestedName
        self.reuseCount = reuseCount
        self.duplicateIndex = duplicateIndex
        self.volumeUUID = volumeUUID
        self.mediaUUID = mediaUUID
        self.bsdNode = bsdNode
        self.mountedPath = mountedPath
        self.fileSystem = fileSystem
        self.isHighConfidence = isHighConfidence
        self.isPhotoOnly = isPhotoOnly
        self.isUnconfiguredCamera = isUnconfiguredCamera
        self.cameraMetadataEvidence = cameraMetadataEvidence
    }
}

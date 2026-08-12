import Foundation

public struct MountedVolume: Identifiable, Hashable {
    // BSD node keeps simultaneously mounted cards distinct even when cloned
    // FAT/exFAT media exposes the same volume UUID.
    public var id: String { "\(volumeUUID ?? "NO-UUID")|\(bsdNode)" }
    public let name: String
    public let originalName: String
    public let path: String
    public let bsdNode: String
    public let volumeUUID: String?
    public let mediaUUID: String?
    public let isRemovable: Bool
    public let isInternal: Bool
    public let freeBytes: Int64
    public let totalBytes: Int64
    public let isGenericName: Bool
    public let fileSystem: String
    
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
    public let estimatedBytes: Int64
    public let savedBytes: Int64
    public let compressionRatioPercent: Int
    
    public var estimatedGBFormatted: String {
        let gb = Double(estimatedBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
    
    public var savedGBFormatted: String {
        let gb = Double(savedBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
    
    public init(isHDESupported: Bool, isCLIAvailable: Bool, cliPath: String?, estimatedBytes: Int64, savedBytes: Int64, compressionRatioPercent: Int = 40) {
        self.isHDESupported = isHDESupported
        self.isCLIAvailable = isCLIAvailable
        self.cliPath = cliPath
        self.estimatedBytes = estimatedBytes
        self.savedBytes = savedBytes
        self.compressionRatioPercent = compressionRatioPercent
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
                needsExifToolInstallation: Bool = false) {
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
    public var volumeUUID: String? = nil
    public var mediaUUID: String? = nil
    public var bsdNode: String? = nil
    public var mountedPath: String? = nil
    
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
                volumeUUID: String? = nil,
                mediaUUID: String? = nil,
                bsdNode: String? = nil,
                mountedPath: String? = nil) {
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
        self.volumeUUID = volumeUUID
        self.mediaUUID = mediaUUID
        self.bsdNode = bsdNode
        self.mountedPath = mountedPath
    }
}

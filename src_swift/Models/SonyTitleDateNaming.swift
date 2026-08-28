import Foundation

public struct SonyTitleDateClipIdentity: Equatable {
    public let titleName: String
    public let cameraLetter: String
    public let recordingDate: String
    public let fileNumber: Int
}

public enum SonyTitleDateNaming {
    public static func parse(_ fileName: String) -> SonyTitleDateClipIdentity? {
        let range = NSRange(location: 0, length: fileName.utf16.count)
        let pattern = #"^(.+)_([0-9]{8})_([0-9]{4})\.(MP4|MOV)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: fileName, options: [], range: range),
              let titleRange = Range(match.range(at: 1), in: fileName),
              let dateRange = Range(match.range(at: 2), in: fileName),
              let numberRange = Range(match.range(at: 3), in: fileName) else { return nil }

        let title = String(fileName[titleRange])
        let recordingDate = String(fileName[dateRange])
        guard title.count <= 37,
              title.range(of: #"^[A-Z0-9.\-_@!#$%+=^~(),;\[\]]+$"#, options: [.regularExpression, .caseInsensitive]) != nil,
              isValidDate(recordingDate),
              let fileNumber = Int(fileName[numberRange]),
              (1...9999).contains(fileNumber),
              let cameraToken = title.split(separator: "_", omittingEmptySubsequences: false).last,
              cameraToken.range(of: #"^FX3[A-Z]$"#, options: [.regularExpression, .caseInsensitive]) != nil,
              let cameraLetter = cameraToken.last else { return nil }

        return SonyTitleDateClipIdentity(
            titleName: title,
            cameraLetter: String(cameraLetter).uppercased(),
            recordingDate: recordingDate,
            fileNumber: fileNumber
        )
    }

    private static func isValidDate(_ value: String) -> Bool {
        guard value.count == 8,
              let year = Int(value.prefix(4)),
              let month = Int(value.dropFirst(4).prefix(2)),
              let day = Int(value.suffix(2)) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return false }
        let verified = calendar.dateComponents([.year, .month, .day], from: date)
        return verified.year == year && verified.month == month && verified.day == day
    }
}

public struct SonyTitleRollAssignment: Equatable {
    public let titleName: String
    public let volumeName: String

    public init(titleName: String, volumeName: String) {
        self.titleName = titleName
        self.volumeName = volumeName
    }
}

public enum SonyTitleRollSequence {
    public static func assignments(from history: [RenameHistoryItem]) -> [SonyTitleRollAssignment] {
        history.compactMap { item in
            guard let firstClipName = item.firstClipName,
                  let identity = SonyTitleDateNaming.parse(firstClipName) else { return nil }
            return SonyTitleRollAssignment(titleName: identity.titleName, volumeName: item.newName)
        }
    }

    public static func resolve(
        scan: ScanResult,
        successfulAssignments: [SonyTitleRollAssignment],
        reservedNames: [String]
    ) -> ScanResult {
        guard scan.suggestedName == nil,
              let titleName = scan.sonyTitleName,
              scan.isScanComplete,
              !scan.isUnformattedCard,
              !scan.isEmptyCard,
              !scan.isPhotoOnly,
              let evidence = scan.cameraMetadataEvidence,
              evidence.manufacturer?.caseInsensitiveCompare("Sony") == .orderedSame,
              evidence.source == .sonyNonRealTimeMeta,
              evidence.confidence == .high,
              evidence.exactModel?.uppercased() == "ILME-FX3",
              let suggestedName = nextVolumeName(
                titleName: titleName,
                successfulAssignments: successfulAssignments,
                reservedNames: reservedNames
              ) else { return scan }

        let cameraLetter = String(suggestedName.prefix(1))
        let rollNumber = String(suggestedName.dropFirst())
        return ScanResult(
            suggestedName: suggestedName,
            cameraLetter: cameraLetter,
            rollNumber: rollNumber,
            suffix: scan.suffix,
            deviceType: scan.deviceType,
            clipCount: scan.clipCount,
            totalFileCount: scan.totalFileCount,
            firstClipName: scan.firstClipName,
            lastClipName: scan.lastClipName,
            isHighConfidence: true,
            isUnconfiguredCamera: scan.isUnconfiguredCamera,
            isEmptyCard: scan.isEmptyCard,
            isPhotoOnly: scan.isPhotoOnly,
            photoCount: scan.photoCount,
            isUnformattedCard: scan.isUnformattedCard,
            dateSpanDays: scan.dateSpanDays,
            earliestDateStr: scan.earliestDateStr,
            latestDateStr: scan.latestDateStr,
            hdeResult: scan.hdeResult,
            isScanComplete: scan.isScanComplete,
            needsExifToolInstallation: scan.needsExifToolInstallation,
            cameraMetadataEvidence: scan.cameraMetadataEvidence,
            sonyTitleName: titleName
        )
    }

    public static func nextVolumeName(
        titleName: String,
        successfulAssignments: [SonyTitleRollAssignment],
        reservedNames: [String]
    ) -> String? {
        let normalizedTitle = normalize(titleName)
        guard let latest = successfulAssignments.first(where: {
            normalize($0.titleName) == normalizedTitle && parseVolumeName($0.volumeName) != nil
        }),
        let base = parseVolumeName(latest.volumeName) else { return nil }

        let reservedRolls = reservedNames.compactMap(parseVolumeName).compactMap { parsed in
            parsed.cameraLetter == base.cameraLetter ? parsed.rollNumber : nil
        }
        let nextRoll = max(base.rollNumber, reservedRolls.max() ?? 0) + 1
        guard nextRoll <= 999 else { return nil }
        return String(format: "%@%03d", base.cameraLetter, nextRoll)
    }

    private static func parseVolumeName(_ name: String) -> (cameraLetter: String, rollNumber: Int)? {
        let normalized = normalize(name)
        let range = NSRange(location: 0, length: normalized.utf16.count)
        guard let regex = try? NSRegularExpression(pattern: #"^([A-Z])([0-9]{3})(?:_|$)"#),
              let match = regex.firstMatch(in: normalized, options: [], range: range),
              let cameraRange = Range(match.range(at: 1), in: normalized),
              let rollRange = Range(match.range(at: 2), in: normalized),
              let roll = Int(normalized[rollRange]) else { return nil }
        return (String(normalized[cameraRange]), roll)
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .uppercased()
    }
}

public enum SonyTitleRemountPolicy {
    public static func wasAlreadyRenamed(
        volumeName: String,
        firstClipName: String?,
        history: [RenameHistoryItem]
    ) -> Bool {
        guard let firstClipName else { return false }
        return history.contains { item in
            item.newName.caseInsensitiveCompare(volumeName) == .orderedSame
                && item.firstClipName == firstClipName
        }
    }
}

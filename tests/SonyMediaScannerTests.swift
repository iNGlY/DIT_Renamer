import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct SonyMediaScannerTests {
    static func main() throws {
        UserDefaults.standard.set(false, forKey: "enableExifToolModelDetection")
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("dit-renamer-sony-tests-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }

        try verifyConfiguredFX3Card(root: root.appendingPathComponent("fx3-configured"))
        try verifyDefaultFX3Card(root: root.appendingPathComponent("fx3-default"))
        try verifyTitleDateFX3CardRequiresInitialRoll(root: root.appendingPathComponent("fx3-title-date"))
        try verifyTitleDateFX3CardRequiresSonyXML(root: root.appendingPathComponent("fx3-title-date-no-xml"))
        verifyTitleDateRollSequence()
        verifyTitleDateScanResolution()
        verifyTitleDateRemountIdentity()
        try verifyConfiguredFX6Card(root: root.appendingPathComponent("fx6-configured"))
        try verifyTakeOnlyXMLDoesNotImpersonateModel(root: root.appendingPathComponent("take-only"))
        print("SonyMediaScannerTests passed")
    }

    private static func verifyConfiguredFX3Card(root: URL) throws {
        let clipDirectory = root.appendingPathComponent("PRIVATE/M4ROOT/CLIP")
        try fmCreate(clipDirectory)
        try Data("placeholder".utf8).write(to: clipDirectory.appendingPathComponent("A247C001_260812AB.MP4"))
        try Data("""
        <?xml version="1.0"?><NonRealTimeMeta><Device manufacturer="Sony" modelName="ILME-FX3"/></NonRealTimeMeta>
        """.utf8).write(to: clipDirectory.appendingPathComponent("A247C001_260812ABM01.XML"))

        let result = MediaScanner.scan(volumePath: root.path)
        require(result.suggestedName == "A247", "Sony cinema filename should yield A247")
        require(result.cameraLetter == "A", "Sony camera letter should be A")
        require(result.rollNumber == "247", "Sony roll should be 247")
        require(result.deviceType.contains("FX3"), "Sony XML should identify FX3")
        require(result.firstClipName?.hasSuffix(".MP4") == true, "FX3 media should remain MP4")
        require(result.isHighConfidence, "complete FX3 M4ROOT structure should be high confidence")
    }

    private static func verifyDefaultFX3Card(root: URL) throws {
        let clipDirectory = root.appendingPathComponent("PRIVATE/M4ROOT/CLIP")
        try fmCreate(clipDirectory)
        try Data("placeholder".utf8).write(to: clipDirectory.appendingPathComponent("C0001.MP4"))
        try Data("""
        <?xml version="1.0"?><NonRealTimeMeta><Device manufacturer="Sony" modelName="ILME-FX3"/></NonRealTimeMeta>
        """.utf8).write(to: clipDirectory.appendingPathComponent("C0001M01.XML"))

        let result = MediaScanner.scan(volumePath: root.path)
        require(result.suggestedName == nil, "default Sony filename must not invent a volume name")
        require(result.isUnconfiguredCamera, "C0001 on Sony structure must require manual assignment")
        require(result.deviceType.contains("FX3"), "Sony XML should identify FX3")
        require(!result.isHighConfidence, "default Sony camera ID must not auto-rename")
    }

    private static func verifyConfiguredFX6Card(root: URL) throws {
        let clipDirectory = root.appendingPathComponent("XDROOT/Clip")
        try fmCreate(clipDirectory)
        try Data("placeholder".utf8).write(to: clipDirectory.appendingPathComponent("B101C001_260812CD.MXF"))
        try Data("""
        <?xml version="1.0"?><NonRealTimeMeta><Device manufacturer="Sony" modelName="ILME-FX6V"/></NonRealTimeMeta>
        """.utf8).write(to: clipDirectory.appendingPathComponent("B101C001_260812CDM01.XML"))

        let result = MediaScanner.scan(volumePath: root.path)
        require(result.suggestedName == "B101", "FX6 cinema filename should yield B101")
        require(result.deviceType.contains("FX6"), "Sony XML should identify FX6 family")
        require(result.firstClipName?.hasSuffix(".MXF") == true, "FX6 media should remain MXF")
        require(result.isHighConfidence, "complete FX6 XDROOT structure should be high confidence")
    }

    private static func verifyTitleDateFX3CardRequiresInitialRoll(root: URL) throws {
        let clipDirectory = root.appendingPathComponent("PRIVATE/M4ROOT/CLIP")
        let proxyDirectory = root.appendingPathComponent("PRIVATE/M4ROOT/SUB")
        try fmCreate(clipDirectory)
        try fmCreate(proxyDirectory)
        try Data("placeholder".utf8).write(to: clipDirectory.appendingPathComponent("B23_FX3B_20260827_0002.mp4"))
        try Data("proxy".utf8).write(to: proxyDirectory.appendingPathComponent("B23_FX3B_20260827_0002S03.MP4"))
        try Data("""
        <?xml version="1.0"?><NonRealTimeMeta><Device manufacturer="Sony" modelName="ILME-FX3"/></NonRealTimeMeta>
        """.utf8).write(to: clipDirectory.appendingPathComponent("B23_FX3B_20260827_0002M01.XML"))

        let result = MediaScanner.scan(volumePath: root.path)
        require(result.deviceType.contains("FX3"), "Sony XML should identify the Title + Date card as FX3")
        require(result.sonyTitleName == "B23_FX3B", "Title + Date parsing should preserve the complete custom title")
        require(result.cameraLetter == "B", "The final FX3B title token should identify camera B")
        require(result.rollNumber == nil, "The four-digit movie file number must not impersonate a reel number")
        require(result.suggestedName == nil, "The first Title + Date card must wait for an operator-provided starting roll")
        require(!result.isHighConfidence, "A Title + Date card without sequence history must not auto-rename")
        require(result.firstClipName == "B23_FX3B_20260827_0002.mp4", "Sony fingerprints should use the primary CLIP media, not SUB proxies")
        let fingerprint = MediaScanner.mediaFingerprint(volumePath: root.path)
        require(fingerprint.firstClipName == result.firstClipName, "Execution revalidation must use the same Sony primary-clip boundary")
    }

    private static func verifyTitleDateFX3CardRequiresSonyXML(root: URL) throws {
        let clipDirectory = root.appendingPathComponent("PRIVATE/M4ROOT/CLIP")
        try fmCreate(clipDirectory)
        try Data("placeholder".utf8).write(to: clipDirectory.appendingPathComponent("B23_FX3A_20260827_0001.MP4"))

        let result = MediaScanner.scan(volumePath: root.path)
        require(result.sonyTitleName == nil, "A filename alone must not activate the FX3 Title + Date workflow")
        require(result.cameraLetter == nil, "FX3A text must not impersonate camera metadata without Sony XML")
        require(!result.isHighConfidence, "A Title + Date filename without model XML must remain low confidence")
    }

    private static func verifyTitleDateRollSequence() {
        require(
            SonyTitleRollSequence.nextVolumeName(
                titleName: "B23_FX3B",
                successfulAssignments: [],
                reservedNames: []
            ) == nil,
            "A Title + Date sequence must require one successful manual assignment"
        )

        let history = [SonyTitleRollAssignment(titleName: "B23_FX3B", volumeName: "B004")]
        require(
            SonyTitleRollSequence.nextVolumeName(
                titleName: "B23_FX3B",
                successfulAssignments: history,
                reservedNames: []
            ) == "B005",
            "The next card should increment the latest successful roll"
        )
        require(
            SonyTitleRollSequence.nextVolumeName(
                titleName: "B23_FX3B",
                successfulAssignments: history,
                reservedNames: ["B005"]
            ) == "B006",
            "Simultaneous cards should reserve sequential rolls instead of duplicate suffixes"
        )
    }

    private static func verifyTitleDateScanResolution() {
        let evidence = CameraMetadataEvidence(
            manufacturer: "Sony",
            exactModel: "ILME-FX3",
            productFamily: "Sony XAVC/XDCAM",
            source: .sonyNonRealTimeMeta,
            confidence: .high,
            isCameraNative: true
        )
        let initial = ScanResult(
            suggestedName: nil,
            cameraLetter: "B",
            rollNumber: nil,
            suffix: nil,
            deviceType: "Sony FX3",
            clipCount: 1,
            totalFileCount: 2,
            firstClipName: "B23_FX3B_20260827_0002.mp4",
            lastClipName: "B23_FX3B_20260827_0002.mp4",
            isHighConfidence: false,
            cameraMetadataEvidence: evidence,
            sonyTitleName: "B23_FX3B"
        )

        let historicalRename = RenameHistoryItem(
            originalName: "Untitled",
            newName: "B004",
            firstClipName: "B23_FX3B_20260826_0001.MP4",
            lastClipName: "B23_FX3B_20260826_0024.MP4",
            clipCount: 24,
            totalFileCount: 48,
            usedSpace: "128 GB",
            deviceType: "Sony FX3",
            timestamp: Date(),
            dateDayString: "2026-08-26"
        )
        let resolved = SonyTitleRollSequence.resolve(
            scan: initial,
            successfulAssignments: SonyTitleRollSequence.assignments(from: [historicalRename]),
            reservedNames: []
        )
        require(resolved.suggestedName == "B005", "A seeded Title + Date sequence should produce the next roll")
        require(resolved.cameraLetter == "B", "Sequence resolution should preserve the seeded output camera letter")
        require(resolved.rollNumber == "005", "Sequence resolution should expose the three-digit reel")
        require(resolved.isHighConfidence, "XML-confirmed Title + Date media with sequence history should become auto-eligible")
        require(resolved.sonyTitleName == "B23_FX3B", "Sequence resolution should preserve the custom title identity")
    }

    private static func verifyTitleDateRemountIdentity() {
        let history = RenameHistoryItem(
            originalName: "Untitled",
            newName: "B004",
            firstClipName: "B23_FX3B_20260826_0001.MP4",
            lastClipName: "B23_FX3B_20260826_0024.MP4",
            clipCount: 24,
            totalFileCount: 48,
            usedSpace: "128 GB",
            deviceType: "Sony FX3",
            timestamp: Date(),
            dateDayString: "2026-08-26"
        )
        require(
            SonyTitleRemountPolicy.wasAlreadyRenamed(
                volumeName: "B004",
                firstClipName: "B23_FX3B_20260826_0001.MP4",
                history: [history]
            ),
            "The successfully renamed card should not return after remount"
        )
        require(
            !SonyTitleRemountPolicy.wasAlreadyRenamed(
                volumeName: "B004",
                firstClipName: "B23_FX3B_20260827_0100.MP4",
                history: [history]
            ),
            "A different card with the same volume name must remain visible"
        )
    }

    private static func verifyTakeOnlyXMLDoesNotImpersonateModel(root: URL) throws {
        let clipDirectory = root.appendingPathComponent("PRIVATE/M4ROOT/CLIP")
        try fmCreate(clipDirectory)
        try Data("placeholder".utf8).write(to: clipDirectory.appendingPathComponent("A001C001_260812EF.MP4"))
        try Data("""
        <?xml version="1.0"?><NonRealTimeMeta><Take><ModelName>ILME-FX9</ModelName></Take></NonRealTimeMeta>
        """.utf8).write(to: clipDirectory.appendingPathComponent("A001C001_260812EFM01.XML"))

        let result = MediaScanner.scan(volumePath: root.path)
        require(!result.deviceType.contains("FX9"), "Sony Take metadata without Device must not impersonate an exact model")
        require(result.cameraMetadataEvidence?.exactModel == nil, "Take-only Sony XML must retain workflow evidence only")
        require(result.cameraMetadataEvidence?.confidence == .low, "Take-only Sony XML must stay low confidence")
    }

    private static func fmCreate(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

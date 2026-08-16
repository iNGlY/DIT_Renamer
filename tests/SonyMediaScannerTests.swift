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

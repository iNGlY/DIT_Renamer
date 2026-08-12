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
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("dit-renamer-sony-tests-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }

        try verifyConfiguredSonyCard(root: root.appendingPathComponent("configured"))
        try verifyDefaultSonyCard(root: root.appendingPathComponent("default"))
        print("SonyMediaScannerTests passed")
    }

    private static func verifyConfiguredSonyCard(root: URL) throws {
        let clipDirectory = root.appendingPathComponent("XDROOT/Clip")
        try fmCreate(clipDirectory)
        try Data("placeholder".utf8).write(to: clipDirectory.appendingPathComponent("A247C001_260812AB.MXF"))
        try Data("""
        <?xml version="1.0"?><NonRealTimeMeta><Device manufacturer="Sony" modelName="ILME-FX3"/></NonRealTimeMeta>
        """.utf8).write(to: clipDirectory.appendingPathComponent("A247C001_260812ABM01.XML"))

        let result = MediaScanner.scan(volumePath: root.path)
        require(result.suggestedName == "A247", "Sony cinema filename should yield A247")
        require(result.cameraLetter == "A", "Sony camera letter should be A")
        require(result.rollNumber == "247", "Sony roll should be 247")
        require(result.deviceType.contains("FX3"), "Sony XML should identify FX3")
        require(result.isHighConfidence, "complete Sony XDROOT structure should be high confidence")
    }

    private static func verifyDefaultSonyCard(root: URL) throws {
        let clipDirectory = root.appendingPathComponent("PRIVATE/M4ROOT/CLIP")
        try fmCreate(clipDirectory)
        try Data("placeholder".utf8).write(to: clipDirectory.appendingPathComponent("C0001.MP4"))
        try Data("""
        <?xml version="1.0"?><NonRealTimeMeta><Device manufacturer="Sony" modelName="ILME-FX6V"/></NonRealTimeMeta>
        """.utf8).write(to: clipDirectory.appendingPathComponent("C0001M01.XML"))

        let result = MediaScanner.scan(volumePath: root.path)
        require(result.suggestedName == nil, "default Sony filename must not invent a volume name")
        require(result.isUnconfiguredCamera, "C0001 on Sony structure must require manual assignment")
        require(result.deviceType.contains("FX6"), "Sony XML should identify FX6 family")
        require(!result.isHighConfidence, "default Sony camera ID must not auto-rename")
    }

    private static func fmCreate(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

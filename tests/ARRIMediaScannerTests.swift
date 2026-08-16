import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct ARRIMediaScannerTests {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("dit-renamer-arri-tests-\(UUID().uuidString)")
        let hdeRoot = URL(fileURLWithPath: root.path + "_hde")
        defer {
            try? fm.removeItem(at: root)
            try? fm.removeItem(at: hdeRoot)
        }

        let reelName = "E_0004_1D6M"
        let rawDirectory = root.appendingPathComponent(reelName)
        let hdeDirectory = hdeRoot.appendingPathComponent(reelName)
        try fm.createDirectory(at: rawDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: hdeDirectory, withIntermediateDirectories: true)
        try Data().write(to: hdeRoot.appendingPathComponent(".codexvfs"))

        let rawName = "E_0004C001_260813_170734_a1D6M.mxf"
        let hdeName = "E_0004C001_260813_170734_h1D6M.mxf"
        let header = "\u{0}\u{1}cameraModel\u{0}ARRI ALEXA 35\u{0}mediumType\u{0}Codex Compact Drive\u{0}"
        var rawData = Data(header.utf8)
        rawData.append(Data(repeating: 0x42, count: 999_000))
        try rawData.write(to: rawDirectory.appendingPathComponent(rawName))
        try Data().write(to: hdeDirectory.appendingPathComponent(hdeName))

        let ale = """
        Heading
        FIELD_DELIM\tTABS

        Column
        Name\tSource File\tOriginal_video\tManufacturer\tCamera_model\tReel_name

        Data
        E_0004C001_260813_170734_a1D6M\t\(rawName)\tARRIRAW (3164p)\tARRI\tALEXA 35\t\(reelName)
        """
        let aleData = Data(ale.utf8)
        try aleData.write(to: rawDirectory.appendingPathComponent("\(reelName)_AVID.ale"))
        try aleData.write(to: hdeDirectory.appendingPathComponent("\(reelName)_AVID.ale"))

        let rawResult = MediaScanner.scan(volumePath: root.path)
        require(rawResult.deviceType == "ARRI ALEXA 35", "ALE metadata should identify ALEXA 35")
        require(rawResult.suggestedName == reelName, "ARRI clip naming should preserve the camera reel name")
        require(rawResult.hdeResult != nil, "ARRIRAW with a paired HDE mount should expose an HDE estimate")
        require(rawResult.hdeResult?.estimatedBytes == Int64(Double(rawData.count) * 0.60), "HDE estimate should use media bytes, not filesystem capacity")

        let hdeResult = MediaScanner.scan(volumePath: hdeRoot.path)
        require(hdeResult.deviceType == "ARRI ALEXA 35", "The HDE companion should inherit the ARRI model from ALE metadata")
        require(hdeResult.hdeResult != nil, "The zero-byte HDE virtual mount should estimate from its paired ARRIRAW source")
        require(hdeResult.hdeResult?.estimatedBytes == Int64(Double(rawData.count) * 0.60), "HDE companion estimate should use paired source media bytes")

        let fallbackRoot = root.appendingPathComponent("mxf-fallback")
        try fm.createDirectory(at: fallbackRoot, withIntermediateDirectories: true)
        let fallbackName = "F_0012C001_260816_120000_a9XYZ.mxf"
        var fallbackData = Data([0xFF, 0x00, 0xFE, 0x00])
        fallbackData.append(Data(#"{"cameraModel" : "ARRI ALEXA Mini LF"}"#.utf8))
        fallbackData.append(Data(repeating: 0x24, count: 4_096))
        try fallbackData.write(to: fallbackRoot.appendingPathComponent(fallbackName))
        let fallbackResult = MediaScanner.scan(volumePath: fallbackRoot.path)
        require(fallbackResult.deviceType == "ARRI ALEXA Mini LF", "Bounded MXF metadata should identify ARRI models when ALE is absent")
        require(fallbackResult.hdeResult != nil, "ARRIRAW MXF fallback detection should still produce an HDE estimate")

        print("ARRIMediaScannerTests passed")
    }
}

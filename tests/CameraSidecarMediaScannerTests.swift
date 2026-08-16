import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func makeRoot(_ name: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("dit-renamer-sidecar-scan-\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
}

private func touch(_ url: URL, bytes: [UInt8] = [0x00, 0x01, 0x02]) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(bytes).write(to: url)
}

@main
struct CameraSidecarMediaScannerTests {
    static func main() throws {
        UserDefaults.standard.set(false, forKey: "enableExifToolModelDetection")
        let fm = FileManager.default

        let redContainerEvidence = MediaScanner.cameraMetadataEvidenceFromExifToolJSON(
            Data("[{\"Make\":\"RED\",\"Model\":\"V-RAPTOR XL 8K VV\",\"SerialNumber\":\"DO-NOT-STORE\"}]".utf8),
            expectedManufacturer: "RED",
            productFamily: "RED R3D workflow",
            sourceFileName: "A001_C001.R3D"
        )
        require(redContainerEvidence?.exactModel == "V-RAPTOR XL 8K VV", "A bounded ExifTool container result may identify an explicit RED model")
        require(redContainerEvidence?.confidence == .medium, "Non-Sony container fallback must remain medium confidence")
        require(redContainerEvidence?.attributes.isEmpty == true, "ExifTool fallback must not retain serial metadata")

        let mismatchedContainerEvidence = MediaScanner.cameraMetadataEvidenceFromExifToolJSON(
            Data("[{\"Make\":\"Canon\",\"Model\":\"EOS C400\"}]".utf8),
            expectedManufacturer: "Nikon",
            productFamily: "Nikon N-RAW",
            sourceFileName: "A001.NEV"
        )
        require(mismatchedContainerEvidence == nil, "Container metadata from another manufacturer must not be accepted")

        let p2 = try makeRoot("p2")
        defer { try? fm.removeItem(at: p2) }
        try touch(p2.appendingPathComponent("CONTENTS/VIDEO/0001AB.MXF"))
        try write(
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <P2Main xmlns="urn:schemas-professionalDisc:nonRealTimeMeta:ver.2.00">
              <ClipMetadata>
                <Device>
                  <Manufacturer>Panasonic</Manufacturer>
                  <ModelName>AJ-PX380</ModelName>
                  <SerialNo>TEST-SERIAL</SerialNo>
                </Device>
              </ClipMetadata>
            </P2Main>
            """,
            to: p2.appendingPathComponent("CONTENTS/CLIP/0001AB.XML")
        )
        let p2Result = MediaScanner.scan(volumePath: p2.path)
        require(p2Result.deviceType == "Panasonic AJ-PX380", "P2 XML must identify the exact Panasonic model")
        require(p2Result.cameraMetadataEvidence?.confidence == .high, "An explicit, consistent P2 Device model must be high-confidence evidence")

        let canon = try makeRoot("canon")
        defer { try? fm.removeItem(at: canon) }
        try touch(canon.appendingPathComponent("CONTENTS/CLIPS001/AA001001.MXF"))
        try write(
            """
            <NewsML-G2>
              <Device><Manufacturer>Canon</Manufacturer><ModelName>EOS C400</ModelName></Device>
              <Headline>User supplied newsroom metadata</Headline>
            </NewsML-G2>
            """,
            to: canon.appendingPathComponent("CONTENTS/CLIPS001/AA001001.XML")
        )
        let canonResult = MediaScanner.scan(volumePath: canon.path)
        require(canonResult.deviceType == "Canon XF Camera Media", "News XML must not impersonate an exact Canon camera model")
        require(canonResult.cameraMetadataEvidence?.confidence == .low, "Canon workflow-only evidence must remain low confidence")

        let red = try makeRoot("red")
        defer { try? fm.removeItem(at: red) }
        try touch(red.appendingPathComponent("A001_0816AB.RDC/A001_C001_0816AB.R3D"))
        try write(
            "<RMD><ISO>800</ISO><ColorSpace>REDWideGamutRGB</ColorSpace></RMD>",
            to: red.appendingPathComponent("A001_0816AB.RDC/A001_C001_0816AB.RMD")
        )
        let redResult = MediaScanner.scan(volumePath: red.path)
        require(redResult.deviceType == "RED Digital Cinema", "An RDC/R3D card must not be captured by Nikon filename rules")
        require(redResult.cameraMetadataEvidence?.confidence == .low, "RMD workflow evidence must not claim an exact RED model")

        let dji = try makeRoot("dji")
        defer { try? fm.removeItem(at: dji) }
        try touch(dji.appendingPathComponent("A001_C001/DJI_0001.DNG"))
        try write(
            "1\n00:00:00,000 --> 00:00:01,000\nISO:800 Shutter:1/50 Aperture:F2.8\n",
            to: dji.appendingPathComponent("A001_C001/DJI_0001.SRT")
        )
        let djiResult = MediaScanner.scan(volumePath: dji.path)
        require(djiResult.deviceType == "DJI Camera Media", "DJI CinemaDNG must not be treated as a photo-only card or hardcoded as Ronin 4D")
        require(djiResult.cameraMetadataEvidence?.confidence == .low, "DJI directory/SRT evidence must remain product-family confidence")

        let genericDNG = try makeRoot("generic-dng")
        defer { try? fm.removeItem(at: genericDNG) }
        try touch(genericDNG.appendingPathComponent("A001_C001/FRAME_0001.DNG"))
        let genericDNGResult = MediaScanner.scan(volumePath: genericDNG.path)
        require(genericDNGResult.deviceType == "Photo Card", "An A001_C001 directory without DJI evidence must not be classified as DJI media")
        require(genericDNGResult.cameraMetadataEvidence == nil, "A generic DNG directory must not invent DJI metadata evidence")

        let nikon = try makeRoot("nikon")
        defer { try? fm.removeItem(at: nikon) }
        try touch(nikon.appendingPathComponent("DCIM/100NCZ_8/A001_C001_0816AB.NEV"))
        let nikonResult = MediaScanner.scan(volumePath: nikon.path)
        require(nikonResult.deviceType == "Nikon N-RAW", "NEV must identify the N-RAW family without guessing ZR, Z8, Z9, or Z6III")
        require(nikonResult.cameraMetadataEvidence?.confidence == .low, "NEV extension alone must not claim an exact Nikon model")

        let braw = try makeRoot("braw")
        defer { try? fm.removeItem(at: braw) }
        try touch(braw.appendingPathComponent("A001_0816_0001.braw"))
        try write(
            """
            {"clipProcessing":{"iso":800,"whiteBalance":{"temperature":5600}},"cameraModel":"Blackmagic URSA Cine 12K"}
            """,
            to: braw.appendingPathComponent("A001_0816_0001.sidecar")
        )
        let brawResult = MediaScanner.scan(volumePath: braw.path)
        require(brawResult.deviceType == "Blackmagic RAW", "Optional BRAW sidecars must identify the workflow, not an exact camera model")
        require(brawResult.cameraMetadataEvidence?.confidence == .low, "BRAW sidecar overrides must remain low confidence")

        print("CameraSidecarMediaScannerTests: PASS")
    }
}

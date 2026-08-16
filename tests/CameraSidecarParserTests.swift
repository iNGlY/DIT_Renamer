import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func document(
    _ format: CameraSidecarFormat,
    _ sourceName: String,
    _ contents: String
) -> CameraSidecarDocument {
    CameraSidecarDocument(
        format: format,
        sourceName: sourceName,
        data: Data(contents.utf8)
    )
}

private func evidence(
    for manufacturer: String,
    in values: [CameraMetadataEvidence]
) -> CameraMetadataEvidence? {
    values.first { $0.manufacturer?.caseInsensitiveCompare(manufacturer) == .orderedSame }
}

@main
struct CameraSidecarParserTests {
    static func main() {
        verifyARRIALE()
        verifySonyNonRealTimeMeta()
        verifyPanasonicP2()
        verifyCanonExplicitFieldsOnly()
        verifyREDRMDAuxiliaryEvidence()
        verifyDJIEvidence()
        verifyNikonNRAWProductFamily()
        verifyBlackmagicSidecarJSON()
        verifyConflictingModelsAreDowngraded()
        verifyMaliciousAndOversizedInputsAreRejected()
        verifyLimitsAreApplied()
        verifyBestEvidenceUsesOnlyCollectedURLs()
        verifyP2BestEvidencePrecedesSonyNamespaceHint()
        print("CameraSidecarParserTests passed")
    }

    private static func verifyARRIALE() {
        let ale = """
        Heading
        FIELD_DELIM\tTABS

        Column
        Name\tSource File\tManufacturer\tCamera_model\tOriginal_video

        Data
        A001C001\tA001C001.mxf\tARRI\tALEXA 35\tARRIRAW
        """
        let values = CameraSidecarParsers.parse([
            document(.arriALE, "A001_AVID.ale", ale)
        ])
        let result = evidence(for: "ARRI", in: values)
        require(result?.exactModel == "ALEXA 35", "ARRI ALE should expose the exact camera model")
        require(result?.productFamily == "ARRI ALEXA/AMIRA", "ARRI ALE should retain its product family")
        require(result?.confidence == .high, "ARRI ALE model should be high confidence")
        require(result?.isCameraNative == true, "ARRI ALE should be marked camera-native")
        require(result?.source == .arriALE, "ARRI ALE should preserve the evidence source")
    }

    private static func verifySonyNonRealTimeMeta() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <nrt:NonRealTimeMeta xmlns:nrt="urn:schemas-professionalDisc:nonRealTimeMeta:ver.2.20">
          <nrt:Device manufacturer="Sony" modelName="ILME-FX6V" serialNo="10001"/>
        </nrt:NonRealTimeMeta>
        """
        let values = CameraSidecarParsers.parse([
            document(.sonyNonRealTimeMetaXML, "XDROOT/Clip/B001M01.XML", xml)
        ])
        let result = evidence(for: "Sony", in: values)
        require(result?.exactModel == "ILME-FX6V", "Sony Device/modelName should expose the exact product identifier")
        require(result?.confidence == .high, "Sony explicit Device metadata should be high confidence")
        require(result?.isCameraNative == true, "Sony NonRealTimeMeta should be camera-native")

        let takeOnly = """
        <NonRealTimeMeta><Duration value="120"/><LtcChangeTable tcFps="25"/></NonRealTimeMeta>
        """
        let takeValues = CameraSidecarParsers.parse([
            document(.sonyNonRealTimeMetaXML, "XDROOT/Take/T001M01.XML", takeOnly)
        ])
        let takeResult = evidence(for: "Sony", in: takeValues)
        require(takeResult?.exactModel == nil, "Sony Take XML without Device must not invent a model")
        require(takeResult?.productFamily == "Sony XAVC/XDCAM", "Sony Take XML may retain workflow evidence")
        require(takeResult?.confidence == .low, "Sony XML without Device should be low confidence")
    }

    private static func verifyPanasonicP2() {
        let xml = """
        <?xml version="1.0"?>
        <P2Main xmlns="urn:schemas-professionalDisc:clipMetadata:ver.3.1">
          <ClipContent>
            <Device>
              <Manufacturer>Panasonic</Manufacturer>
              <ModelName>AU-EVA1</ModelName>
              <SerialNo>42</SerialNo>
            </Device>
          </ClipContent>
        </P2Main>
        """
        let values = CameraSidecarParsers.parse([
            document(.panasonicP2XML, "CONTENTS/CLIP/0001AB.XML", xml)
        ])
        let result = evidence(for: "Panasonic", in: values)
        require(result?.exactModel == "AU-EVA1", "P2 Device/ModelName should expose the exact model")
        require(result?.productFamily == "Panasonic P2/VariCam", "P2 XML should retain its product family")
        require(result?.confidence == .high, "P2 device metadata should be high confidence")
        require(result?.isCameraNative == true, "P2 clip metadata should be camera-native")
    }

    private static func verifyCanonExplicitFieldsOnly() {
        let explicitXMP = """
        <x:xmpmeta xmlns:x="adobe:ns:meta/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:tiff="http://ns.adobe.com/tiff/1.0/">
          <rdf:RDF><rdf:Description tiff:Make="Canon" tiff:Model="EOS C400"/></rdf:RDF>
        </x:xmpmeta>
        """
        let explicitValues = CameraSidecarParsers.parse([
            document(.canonXMLOrXMP, "CONTENTS/CLIPS001/A001C001.XMP", explicitXMP)
        ])
        let explicit = evidence(for: "Canon", in: explicitValues)
        require(explicit?.exactModel == "EOS C400", "Canon explicit Make/Model should be preserved")
        require(explicit?.confidence == .medium, "Canon sidecar model should not be promoted to high confidence")
        require(explicit?.isCameraNative == false, "Generic Canon XMP cannot be assumed camera-native")

        let newsXML = """
        <NewsItem><Description>Shot on Canon EOS C500 Mark II</Description><Creator>DIT</Creator></NewsItem>
        """
        let newsValues = CameraSidecarParsers.parse([
            document(.canonXMLOrXMP, "NEWS/metadata.xml", newsXML)
        ])
        let news = evidence(for: "Canon", in: newsValues)
        require(news?.exactModel == nil, "Free-text Canon news metadata must not be treated as an explicit model field")
        require(news?.productFamily == "Canon XF/Cinema EOS workflow", "Canon XML may retain workflow evidence")

        let explicitNewsItem = """
        <NewsItem><Manufacturer>Canon</Manufacturer><ModelName>EOS C400</ModelName></NewsItem>
        """
        let explicitNewsItemResult = evidence(for: "Canon", in: CameraSidecarParsers.parse([
            document(.canonXMLOrXMP, "NEWS/explicit-news-item.xml", explicitNewsItem)
        ]))
        require(explicitNewsItemResult?.exactModel == nil, "Canon NewsItem fields are user content and must not expose an exact camera model")
        require(explicitNewsItemResult?.productFamily == "Canon XF/Cinema EOS workflow", "Canon NewsItem should retain only workflow/family evidence")
        require(explicitNewsItemResult?.source == .workflowSidecar, "Canon NewsItem should be classified as workflow sidecar evidence")
        require(explicitNewsItemResult?.confidence == .low, "Canon NewsItem must remain low confidence")

        let namespacedNewsML = """
        <news:newsItem xmlns:news="http://iptc.org/std/nar/2006-10-01/">
          <news:contentMeta>
            <news:Manufacturer>Canon</news:Manufacturer>
            <news:ModelName>EOS C500 Mark II</news:ModelName>
          </news:contentMeta>
        </news:newsItem>
        """
        let namespacedNewsMLResult = evidence(for: "Canon", in: CameraSidecarParsers.parse([
            document(.canonXMLOrXMP, "NEWS/newsml-g2.xml", namespacedNewsML)
        ]))
        require(namespacedNewsMLResult?.exactModel == nil, "Namespaced NewsML-G2 must not expose an exact Canon model")
        require(namespacedNewsMLResult?.source == .workflowSidecar, "NewsML-G2 should remain workflow sidecar evidence")

        let exactNewsMLG2Root = """
        <NewsML-G2>
          <Manufacturer>Canon</Manufacturer>
          <ModelName>EOS C400</ModelName>
        </NewsML-G2>
        """
        let exactNewsMLG2Result = evidence(for: "Canon", in: CameraSidecarParsers.parse([
            document(.canonXMLOrXMP, "NEWS/exact-newsml-g2.xml", exactNewsMLG2Root)
        ]))
        require(exactNewsMLG2Result?.exactModel == nil, "Exact NewsML-G2 root must not expose EOS C400")
        require(exactNewsMLG2Result?.productFamily == "Canon XF/Cinema EOS workflow", "Exact NewsML-G2 root should retain only Canon workflow/family evidence")
        require(exactNewsMLG2Result?.source == .workflowSidecar, "Exact NewsML-G2 root should use workflow sidecar evidence")
        require(exactNewsMLG2Result?.confidence == .low, "Exact NewsML-G2 root must remain low confidence")

        let nestedNewsMetadata = """
        <ClipMetadata>
          <NewsMetadata>
            <Device><Manufacturer>Canon</Manufacturer><ModelName>EOS C300 Mark III</ModelName></Device>
          </NewsMetadata>
        </ClipMetadata>
        """
        let nestedNewsMetadataResult = evidence(for: "Canon", in: CameraSidecarParsers.parse([
            document(.canonXMLOrXMP, "CONTENTS/CLIPS001/news-metadata.xml", nestedNewsMetadata)
        ]))
        require(nestedNewsMetadataResult?.exactModel == nil, "Nested Canon NewsMetadata must override explicit Device model fields")
        require(nestedNewsMetadataResult?.productFamily == "Canon XF/Cinema EOS workflow", "Nested NewsMetadata should retain Canon workflow/family evidence")

        let lensOnly = """
        <Metadata><Creator>Adobe</Creator><Lens><Manufacturer>Canon</Manufacturer><Model>CN-E 50mm</Model></Lens></Metadata>
        """
        let lensValues = CameraSidecarParsers.parse([
            document(.canonXMLOrXMP, "post-generated.xmp", lensOnly)
        ])
        let lens = evidence(for: "Canon", in: lensValues)
        require(lens?.exactModel == nil, "Lens manufacturer/model fields must not be promoted to a Canon camera model")
    }

    private static func verifyREDRMDAuxiliaryEvidence() {
        let gradingOnly = """
        <RMD><ColorVersion>3</ColorVersion><ISO>800</ISO><Kelvin>5600</Kelvin><CameraID>A</CameraID></RMD>
        """
        let gradingValues = CameraSidecarParsers.parse([
            document(.redRMD, "A001_C001_0816AB.RMD", gradingOnly)
        ])
        let grading = evidence(for: "RED", in: gradingValues)
        require(grading?.exactModel == nil, "RED CameraID and grading values must not be interpreted as a camera model")
        require(grading?.productFamily == "RED R3D workflow", "RMD should provide workflow-level evidence")
        require(grading?.confidence == .low, "RMD without explicit manufacturer/model should remain low confidence")
        require(grading?.isCameraNative == false, "RMD may be written by post software")

        let explicit = """
        <RMD><Manufacturer>RED</Manufacturer><CameraModel>V-RAPTOR XL</CameraModel></RMD>
        """
        let explicitResult = evidence(for: "RED", in: CameraSidecarParsers.parse([
            document(.redRMD, "A001_C001_0816AB.RMD", explicit)
        ]))
        require(explicitResult?.exactModel == nil, "RED RMD must not expose an exact model even when Manufacturer/CameraModel are present")
        require(explicitResult?.productFamily == "RED R3D workflow", "Explicit RMD fields should retain only the RED workflow family")
        require(explicitResult?.source == .workflowSidecar, "RED RMD must remain workflow sidecar evidence")
        require(explicitResult?.confidence == .low, "RED RMD must remain low confidence")
    }

    private static func verifyDJIEvidence() {
        let srt = """
        1
        00:00:00,000 --> 00:00:01,000
        [iso: 800] [shutter: 1/50] [fnum: 2.8] [ev: 0] [ct: 5600]
        """
        let srtResult = evidence(for: "DJI", in: CameraSidecarParsers.parse([
            document(.djiSRT, "DCIM/DJI_0001.SRT", srt)
        ]))
        require(srtResult?.exactModel == nil, "DJI telemetry SRT must not imply Ronin 4D or Inspire 3")
        require(srtResult?.productFamily == "DJI camera workflow", "DJI SRT should retain workflow evidence")

        let xmp = """
        <x:xmpmeta xmlns:x="adobe:ns:meta/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:tiff="http://ns.adobe.com/tiff/1.0/">
          <rdf:RDF><rdf:Description tiff:Make="DJI" tiff:Model="Zenmuse X9-8K Air"/></rdf:RDF>
        </x:xmpmeta>
        """
        let xmpResult = evidence(for: "DJI", in: CameraSidecarParsers.parse([
            document(.djiXMP, "DJI_0001.XMP", xmp)
        ]))
        require(xmpResult?.exactModel == "Zenmuse X9-8K Air", "DJI XMP may expose an explicit model")
        require(xmpResult?.confidence == .medium, "DJI XMP should remain medium confidence")

        let directoryResult = evidence(for: "DJI", in: CameraSidecarParsers.parse([
            CameraSidecarDocument(format: .djiDirectoryEvidence, sourceName: "DCIM/DJI_001", data: Data())
        ]))
        require(directoryResult?.exactModel == nil, "DJI directory evidence must not guess a specific camera")
        require(directoryResult?.source == .directorySignature, "DJI directory evidence should identify its source type")
    }

    private static func verifyNikonNRAWProductFamily() {
        let values = CameraSidecarParsers.parse([
            CameraSidecarDocument(format: .nikonNRAW, sourceName: "VIDEO/NC_D001.NEV", data: Data())
        ])
        let result = evidence(for: "Nikon", in: values)
        require(result?.exactModel == nil, "The NEV extension cannot distinguish Nikon camera models")
        require(result?.productFamily == "Nikon N-RAW", "NEV evidence should identify only the N-RAW family")
        require(result?.confidence == .low, "N-RAW family evidence should remain low confidence")

        let explicitXMP = """
        <x:xmpmeta xmlns:x="adobe:ns:meta/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:tiff="http://ns.adobe.com/tiff/1.0/">
          <rdf:RDF><rdf:Description tiff:Make="Nikon" tiff:Model="Z9"/></rdf:RDF>
        </x:xmpmeta>
        """
        let explicit = evidence(for: "Nikon", in: CameraSidecarParsers.parse([
            document(.nikonNRAW, "NC_D001.XMP", explicitXMP)
        ]))
        require(explicit?.exactModel == nil, "Nikon sidecar must not expose an exact model even when Make/Model are paired")
        require(explicit?.productFamily == "Nikon N-RAW", "Nikon sidecar should retain only the N-RAW family")
        require(explicit?.source == .workflowSidecar, "Nikon sidecar should remain workflow sidecar evidence")
        require(explicit?.confidence == .low, "Nikon sidecar must remain low confidence")
        require(explicit?.isCameraNative == false, "A generic Nikon XMP cannot be assumed camera-native")
    }

    private static func verifyBlackmagicSidecarJSON() {
        let gradingOnly = #"{"clipProcessing":{"iso":1250,"whiteBalance":5600},"comment":"Pocket Cinema Camera 6K"}"#
        let grading = evidence(for: "Blackmagic Design", in: CameraSidecarParsers.parse([
            document(.blackmagicBRAWJSON, "A001_0001.braw.sidecar", gradingOnly)
        ]))
        require(grading?.exactModel == nil, "A model mentioned only in a BRAW comment must not be reported")
        require(grading?.productFamily == "Blackmagic RAW", "BRAW sidecar should retain workflow evidence")
        require(grading?.isCameraNative == false, "BRAW sidecars are post-adjustment files")

        let explicitJSON = #"{"metadata":{"manufacturer":"Blackmagic Design","cameraModel":"URSA Cine 12K LF"},"iso":800}"#
        let explicit = evidence(for: "Blackmagic Design", in: CameraSidecarParsers.parse([
            document(.blackmagicBRAWJSON, "A001_0001.braw.sidecar", explicitJSON)
        ]))
        require(explicit?.exactModel == nil, "BRAW sidecar must not expose an exact model even when cameraModel is present")
        require(explicit?.productFamily == "Blackmagic RAW", "BRAW sidecar should retain only the Blackmagic RAW family")
        require(explicit?.source == .workflowSidecar, "BRAW sidecar must remain workflow sidecar evidence")
        require(explicit?.confidence == .low, "BRAW sidecar must remain low confidence")
    }

    private static func verifyConflictingModelsAreDowngraded() {
        let fx3 = #"<NonRealTimeMeta><Device manufacturer="Sony" modelName="ILME-FX3"/></NonRealTimeMeta>"#
        let fx6 = #"<NonRealTimeMeta><Device manufacturer="Sony" modelName="ILME-FX6V"/></NonRealTimeMeta>"#
        let values = CameraSidecarParsers.parse([
            document(.sonyNonRealTimeMetaXML, "C0001M01.XML", fx3),
            document(.sonyNonRealTimeMetaXML, "C0002M01.XML", fx6)
        ])
        let result = evidence(for: "Sony", in: values)
        require(result?.exactModel == nil, "Conflicting Sony models must not select the first file")
        require(result?.confidence == .low, "Conflicting model evidence should be downgraded")
        require(result?.source == .workflowSidecar, "Conflicting models should use the shared workflow source")
        require(result?.attributes["conflict"] == "true", "Conflicting models should be explicit in evidence attributes")
    }

    private static func verifyMaliciousAndOversizedInputsAreRejected() {
        let malicious = """
        <?xml version="1.0"?>
        <!DOCTYPE x [<!ENTITY leak SYSTEM "file:///etc/passwd">]>
        <NonRealTimeMeta><Device manufacturer="Sony" modelName="&leak;"/></NonRealTimeMeta>
        """
        let maliciousValues = CameraSidecarParsers.parse([
            document(.sonyNonRealTimeMetaXML, "malicious.XML", malicious)
        ])
        require(maliciousValues.isEmpty, "XML containing DTD/entity declarations must be rejected")

        let oversized = CameraSidecarDocument(
            format: .arriALE,
            sourceName: "oversized.ale",
            data: Data(repeating: 0x41, count: 129)
        )
        let oversizedValues = CameraSidecarParsers.parse(
            [oversized],
            limits: CameraSidecarParserLimits(maxFileBytes: 128)
        )
        require(oversizedValues.isEmpty, "Files above maxFileBytes must be rejected before parsing")
    }

    private static func verifyLimitsAreApplied() {
        let longModel = String(repeating: "X", count: 65)
        let xml = "<NonRealTimeMeta><Device manufacturer=\"Sony\" modelName=\"\(longModel)\"/></NonRealTimeMeta>"
        let fieldLimited = evidence(for: "Sony", in: CameraSidecarParsers.parse(
            [document(.sonyNonRealTimeMetaXML, "long.XML", xml)],
            limits: CameraSidecarParserLimits(maxFieldLength: 64)
        ))
        require(fieldLimited?.exactModel == nil, "Fields above maxFieldLength must not become model evidence")

        let first = #"<NonRealTimeMeta><Device manufacturer="Sony" modelName="ILME-FX3"/></NonRealTimeMeta>"#
        let second = #"<NonRealTimeMeta><Device manufacturer="Sony" modelName="ILME-FX6V"/></NonRealTimeMeta>"#
        let fileLimited = evidence(for: "Sony", in: CameraSidecarParsers.parse(
            [
                document(.sonyNonRealTimeMetaXML, "first.XML", first),
                document(.sonyNonRealTimeMetaXML, "second.XML", second)
            ],
            limits: CameraSidecarParserLimits(maxFileCount: 1)
        ))
        require(fileLimited?.exactModel == "ILME-FX3", "maxFileCount should bound the number of parsed candidates")
    }

    private static func verifyBestEvidenceUsesOnlyCollectedURLs() {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("dit-sidecar-url-tests-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            let collected = root.appendingPathComponent("C0001M01.XML")
            let uncollected = root.appendingPathComponent("C0002M01.XML")
            try Data(#"<NonRealTimeMeta><Device manufacturer="Sony" modelName="ILME-FX3"/></NonRealTimeMeta>"#.utf8)
                .write(to: collected)
            try Data(#"<NonRealTimeMeta><Device manufacturer="Sony" modelName="ILME-FX6V"/></NonRealTimeMeta>"#.utf8)
                .write(to: uncollected)

            let result = CameraSidecarParsers.bestEvidence(
                sidecarURLs: [collected],
                directoryNames: ["PRIVATE", "M4ROOT", "CLIP"],
                mediaExtensions: ["mp4"]
            )
            require(result?.exactModel == "ILME-FX3", "URL integration entry should parse the supplied Sony sidecar")
            require(result?.source.rawValue == "sony-non-real-time-meta", "Evidence source rawValue should be stable for audit output")
            require(result?.confidence.rawValue == "high", "Confidence rawValue should be stable for audit output")
        } catch {
            fputs("FAIL: URL integration fixture failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func verifyP2BestEvidencePrecedesSonyNamespaceHint() {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("dit-p2-url-tests-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)

            let p2MainURL = root.appendingPathComponent("0001AB.XML")
            let p2Main = """
            <?xml version="1.0"?>
            <P2Main xmlns="urn:schemas-professionalDisc:nonRealTimeMeta:ver.1.00">
              <ClipContent><Device><Manufacturer>Panasonic</Manufacturer><ModelName>AJ-PX380</ModelName></Device></ClipContent>
            </P2Main>
            """
            try Data(p2Main.utf8).write(to: p2MainURL)

            let rootEvidence = CameraSidecarParsers.bestEvidence(
                sidecarURLs: [p2MainURL],
                directoryNames: [],
                mediaExtensions: ["mxf"]
            )
            require(rootEvidence?.manufacturer == "Panasonic", "P2Main root must take priority over a nonRealTimeMeta namespace hint")
            require(rootEvidence?.exactModel == "AJ-PX380", "P2Main URL parsing should retain the AJ-PX380 model")
            require(rootEvidence?.source == .panasonicP2XML, "P2Main URL parsing should retain the Panasonic P2 source")
            require(rootEvidence?.confidence == .high, "P2Main Device metadata should remain high confidence")

            let directoryHintURL = root.appendingPathComponent("0002AB.XML")
            let directoryHintXML = """
            <?xml version="1.0"?>
            <ClipMetadata xmlns="urn:schemas-professionalDisc:nonRealTimeMeta:ver.1.00">
              <Device><Manufacturer>Panasonic</Manufacturer><ModelName>AJ-PX380</ModelName></Device>
            </ClipMetadata>
            """
            try Data(directoryHintXML.utf8).write(to: directoryHintURL)

            let directoryEvidence = CameraSidecarParsers.bestEvidence(
                sidecarURLs: [directoryHintURL],
                directoryNames: ["CONTENTS", "CLIP"],
                mediaExtensions: ["mxf"]
            )
            require(directoryEvidence?.manufacturer == "Panasonic", "P2 directory evidence must take priority over a nonRealTimeMeta namespace hint")
            require(directoryEvidence?.exactModel == "AJ-PX380", "P2 directory URL parsing should retain the AJ-PX380 model")
            require(directoryEvidence?.source == .panasonicP2XML, "P2 directory URL parsing should use the Panasonic P2 source")
        } catch {
            fputs("FAIL: P2 URL integration fixture failed: \(error)\n", stderr)
            exit(1)
        }
    }
}

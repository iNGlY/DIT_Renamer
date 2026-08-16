import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public enum CameraSidecarFormat: Sendable {
    case arriALE
    case sonyNonRealTimeMetaXML
    case panasonicP2XML
    case canonXMLOrXMP
    case redRMD
    case djiSRT
    case djiXMP
    case djiDirectoryEvidence
    case nikonNRAW
    case blackmagicBRAWJSON
}

public struct CameraSidecarDocument: Sendable {
    public let format: CameraSidecarFormat
    public let sourceName: String
    public let data: Data

    public init(format: CameraSidecarFormat, sourceName: String, data: Data) {
        self.format = format
        self.sourceName = sourceName
        self.data = data
    }
}

public struct CameraSidecarParserLimits: Sendable {
    public let maxFileBytes: Int
    public let maxFieldLength: Int
    public let maxFileCount: Int
    public let maxXMLDepth: Int
    public let maxXMLNodes: Int

    public init(
        maxFileBytes: Int = 4_194_304,
        maxFieldLength: Int = 256,
        maxFileCount: Int = 32,
        maxXMLDepth: Int = 64,
        maxXMLNodes: Int = 4_096
    ) {
        self.maxFileBytes = max(0, maxFileBytes)
        self.maxFieldLength = max(0, maxFieldLength)
        self.maxFileCount = max(0, maxFileCount)
        self.maxXMLDepth = max(0, maxXMLDepth)
        self.maxXMLNodes = max(0, maxXMLNodes)
    }
}

public enum CameraSidecarParsers {
    public static func parse(
        _ documents: [CameraSidecarDocument],
        limits: CameraSidecarParserLimits = CameraSidecarParserLimits()
    ) -> [CameraMetadataEvidence] {
        guard limits.maxFileCount > 0 else { return [] }

        var parsed: [CameraMetadataEvidence] = []
        for document in documents.prefix(limits.maxFileCount) {
            guard document.data.count <= limits.maxFileBytes else { continue }
            if let value = parse(document, limits: limits) {
                parsed.append(value)
            }
        }
        return consolidate(parsed, maxFieldLength: limits.maxFieldLength)
    }

    public static func parse(
        url: URL,
        as format: CameraSidecarFormat,
        limits: CameraSidecarParserLimits = CameraSidecarParserLimits()
    ) -> CameraMetadataEvidence? {
        guard let data = boundedData(from: url, maxBytes: limits.maxFileBytes) else { return nil }
        return parse([
            CameraSidecarDocument(
                format: format,
                sourceName: url.lastPathComponent,
                data: data
            )
        ], limits: limits).first
    }

    /// Uses only candidates gathered by the caller's existing volume enumeration.
    /// This method never walks a directory or opens media files.
    public static func bestEvidence(
        sidecarURLs: [URL],
        directoryNames: Set<String>,
        mediaExtensions: Set<String>,
        limits: CameraSidecarParserLimits = CameraSidecarParserLimits()
    ) -> CameraMetadataEvidence? {
        guard limits.maxFileCount > 0 else { return nil }
        let normalizedDirectories = Set(directoryNames.map { $0.lowercased() })
        let normalizedExtensions = Set(mediaExtensions.map {
            $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        })
        var documents: [CameraSidecarDocument] = []

        for url in sidecarURLs.prefix(limits.maxFileCount) {
            guard let data = boundedData(from: url, maxBytes: limits.maxFileBytes),
                  let format = inferredFormat(
                      for: url,
                      data: data,
                      directoryNames: normalizedDirectories
                  ) else { continue }
            documents.append(CameraSidecarDocument(
                format: format,
                sourceName: url.lastPathComponent,
                data: data
            ))
        }

        var values = parse(documents, limits: limits)
        values.append(contentsOf: directoryAndExtensionEvidence(
            directoryNames: normalizedDirectories,
            mediaExtensions: normalizedExtensions
        ))
        let consolidated = consolidate(values, maxFieldLength: limits.maxFieldLength)
        return consolidated.max { lhs, rhs in
            evidencePriority(lhs) < evidencePriority(rhs)
        }
    }

    private static func boundedData(from url: URL, maxBytes: Int) -> Data? {
        guard maxBytes >= 0,
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true,
              (values.fileSize ?? 0) <= maxBytes,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let readLimit = maxBytes == Int.max ? Int.max : maxBytes + 1
        guard let data = try? handle.read(upToCount: readLimit),
              data.count <= maxBytes else { return nil }
        return data
    }

    private static func inferredFormat(
        for url: URL,
        data: Data,
        directoryNames: Set<String>
    ) -> CameraSidecarFormat? {
        let extensionName = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent.lowercased()
        switch extensionName {
        case "ale":
            return .arriALE
        case "rmd":
            return .redRMD
        case "srt":
            return fileName.hasPrefix("dji_") || directoryNames.contains("dji") ? .djiSRT : nil
        case "sidecar":
            return fileName.contains(".braw.") ? .blackmagicBRAWJSON : nil
        case "xml", "xmp":
            let probe = String(decoding: data, as: UTF8.self).lowercased()
            if probe.contains("p2main")
                || (directoryNames.contains("contents") && directoryNames.contains("clip")) {
                return .panasonicP2XML
            }
            if probe.contains("nonrealtimemeta")
                || directoryNames.contains("m4root")
                || directoryNames.contains("xdroot") {
                return .sonyNonRealTimeMetaXML
            }
            if fileName.hasPrefix("dji_")
                || directoryNames.contains("dji")
                || probe.contains("manufacturer=\"dji\"")
                || probe.contains("make=\"dji\"") {
                return .djiXMP
            }
            if directoryNames.contains("xfvc")
                || directoryNames.contains("clips001")
                || probe.contains("manufacturer=\"canon\"")
                || probe.contains("make=\"canon\"") {
                return .canonXMLOrXMP
            }
            if probe.contains("manufacturer=\"nikon\"")
                || probe.contains("make=\"nikon\"") {
                return .nikonNRAW
            }
            return nil
        default:
            return nil
        }
    }

    private static func directoryAndExtensionEvidence(
        directoryNames: Set<String>,
        mediaExtensions: Set<String>
    ) -> [CameraMetadataEvidence] {
        var values: [CameraMetadataEvidence] = []
        func append(
            manufacturer: String,
            family: String,
            isCameraNative: Bool = true
        ) {
            values.append(CameraMetadataEvidence(
                manufacturer: manufacturer,
                exactModel: nil,
                productFamily: family,
                source: .directorySignature,
                confidence: .low,
                isCameraNative: isCameraNative,
                sourceFileName: nil
            ))
        }

        if directoryNames.contains("m4root") || directoryNames.contains("xdroot") {
            append(manufacturer: "Sony", family: "Sony XAVC/XDCAM")
        }
        if directoryNames.contains("contents") && directoryNames.contains("clip") {
            append(manufacturer: "Panasonic", family: "Panasonic P2/VariCam")
        }
        if directoryNames.contains("xfvc") || directoryNames.contains("clips001") {
            append(manufacturer: "Canon", family: "Canon XF/Cinema EOS workflow")
        }
        if directoryNames.contains("dji") {
            append(manufacturer: "DJI", family: "DJI camera workflow")
        }
        if mediaExtensions.contains("r3d") {
            append(manufacturer: "RED", family: "RED R3D workflow")
        }
        if mediaExtensions.contains("nev") {
            append(manufacturer: "Nikon", family: "Nikon N-RAW")
        }
        if mediaExtensions.contains("braw") {
            append(manufacturer: "Blackmagic Design", family: "Blackmagic RAW", isCameraNative: false)
        }
        return values
    }

    private static func evidencePriority(_ value: CameraMetadataEvidence) -> (Int, Int, Int, String) {
        (
            confidenceRank(value.confidence),
            value.exactModel == nil ? 0 : 1,
            value.isCameraNative ? 1 : 0,
            value.source.rawValue
        )
    }

    private static func parse(
        _ document: CameraSidecarDocument,
        limits: CameraSidecarParserLimits
    ) -> CameraMetadataEvidence? {
        switch document.format {
        case .arriALE:
            return parseARRIALE(document, limits: limits)
        case .sonyNonRealTimeMetaXML:
            return parseSonyXML(document, limits: limits)
        case .panasonicP2XML:
            return parsePanasonicP2XML(document, limits: limits)
        case .canonXMLOrXMP:
            return parseCanonXML(document, limits: limits)
        case .redRMD:
            return parseREDRMD(document, limits: limits)
        case .djiSRT:
            return parseDJISRT(document, limits: limits)
        case .djiXMP:
            return parseDJIXMP(document, limits: limits)
        case .djiDirectoryEvidence:
            return CameraMetadataEvidence(
                manufacturer: "DJI",
                exactModel: nil,
                productFamily: "DJI camera workflow",
                source: .directorySignature,
                confidence: .low,
                isCameraNative: true,
                sourceFileName: document.sourceName
            )
        case .nikonNRAW:
            return parseNikonNRAW(document, limits: limits)
        case .blackmagicBRAWJSON:
            return parseBlackmagicBRAWJSON(document, limits: limits)
        }
    }

    private static func parseARRIALE(
        _ document: CameraSidecarDocument,
        limits: CameraSidecarParserLimits
    ) -> CameraMetadataEvidence? {
        guard !document.data.isEmpty else { return nil }
        let text = String(decoding: document.data, as: UTF8.self)
        let lines = text.components(separatedBy: .newlines)
        guard let columnMarker = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Column") == .orderedSame
        }),
        let headerIndex = lines.indices.dropFirst(columnMarker + 1).first(where: {
            !isBlank(lines[$0])
        }),
        let dataMarker = lines.indices.dropFirst(headerIndex + 1).first(where: {
            lines[$0].trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Data") == .orderedSame
        }) else { return nil }

        let headers = lines[headerIndex].components(separatedBy: "\t").map(normalizedKey)
        let manufacturerIndex = firstIndex(in: headers, matching: ["manufacturer", "make"])
        let modelIndex = firstIndex(in: headers, matching: ["cameramodel", "modelname"])
        let originalVideoIndex = firstIndex(in: headers, matching: ["originalvideo"])
        var models = Set<String>()
        var hasARRIEvidence = false

        for line in lines.dropFirst(dataMarker + 1) where !isBlank(line) {
            let fields = line.components(separatedBy: "\t")
            let manufacturer = value(at: manufacturerIndex, in: fields, limits: limits)
            let model = value(at: modelIndex, in: fields, limits: limits)
            let originalVideo = value(at: originalVideoIndex, in: fields, limits: limits)
            let manufacturerIsARRI = manufacturer?.range(of: "ARRI", options: .caseInsensitive) != nil
            let modelIsARRI = model.map(isARRICameraModel) ?? false
            let isARRIRAW = originalVideo?.range(of: "ARRIRAW", options: .caseInsensitive) != nil
            hasARRIEvidence = hasARRIEvidence || manufacturerIsARRI || modelIsARRI || isARRIRAW
            if modelIsARRI, let model {
                models.insert(normalizedARRIModel(model))
            }
        }

        guard hasARRIEvidence else { return nil }
        if models.count > 1 {
            return conflictEvidence(
                manufacturer: "ARRI",
                productFamily: "ARRI ALEXA/AMIRA",
                isCameraNative: true,
                sourceName: document.sourceName
            )
        }
        return CameraMetadataEvidence(
            manufacturer: "ARRI",
            exactModel: models.first,
            productFamily: "ARRI ALEXA/AMIRA",
            source: .arriALE,
            confidence: models.isEmpty ? .low : .high,
            isCameraNative: true,
            sourceFileName: document.sourceName
        )
    }

    private static func parseSonyXML(
        _ document: CameraSidecarDocument,
        limits: CameraSidecarParserLimits
    ) -> CameraMetadataEvidence? {
        guard let xml = parseXML(document.data, limits: limits),
              normalizedKey(xml.rootName) == "nonrealtimemeta" else { return nil }

        var models = Set<String>()
        for node in xml.nodes where normalizedKey(node.name) == "device" {
            let manufacturer = attributeValue(
                in: node,
                keys: ["manufacturer", "make"],
                maxFieldLength: limits.maxFieldLength
            )
            let model = attributeValue(
                in: node,
                keys: ["modelname", "cameramodel", "model"],
                maxFieldLength: limits.maxFieldLength
            )
            if containsToken(manufacturer, "sony"), let model {
                models.insert(model)
            }
        }

        if models.count > 1 {
            return conflictEvidence(
                manufacturer: "Sony",
                productFamily: "Sony XAVC/XDCAM",
                isCameraNative: true,
                sourceName: document.sourceName
            )
        }
        return CameraMetadataEvidence(
            manufacturer: "Sony",
            exactModel: models.first,
            productFamily: "Sony XAVC/XDCAM",
            source: .sonyNonRealTimeMeta,
            confidence: models.isEmpty ? .low : .high,
            isCameraNative: true,
            sourceFileName: document.sourceName
        )
    }

    private static func parsePanasonicP2XML(
        _ document: CameraSidecarDocument,
        limits: CameraSidecarParserLimits
    ) -> CameraMetadataEvidence? {
        guard let xml = parseXML(document.data, limits: limits) else { return nil }
        let deviceNodes = xml.nodes.filter { node in
            node.path.map(normalizedKey).contains("device")
        }
        let manufacturers = fieldValues(
            in: deviceNodes,
            keys: ["manufacturer", "make"],
            maxFieldLength: limits.maxFieldLength
        ).filter { containsToken($0, "panasonic") }
        let models = Set(fieldValues(
            in: deviceNodes,
            keys: ["modelname", "cameramodel", "devicemodel"],
            maxFieldLength: limits.maxFieldLength
        ))

        if !manufacturers.isEmpty, models.count > 1 {
            return conflictEvidence(
                manufacturer: "Panasonic",
                productFamily: "Panasonic P2/VariCam",
                isCameraNative: true,
                sourceName: document.sourceName
            )
        }
        let exactModel = manufacturers.isEmpty ? nil : models.first
        return CameraMetadataEvidence(
            manufacturer: "Panasonic",
            exactModel: exactModel,
            productFamily: "Panasonic P2/VariCam",
            source: .panasonicP2XML,
            confidence: exactModel == nil ? .low : .high,
            isCameraNative: true,
            sourceFileName: document.sourceName
        )
    }

    private static func parseCanonXML(
        _ document: CameraSidecarDocument,
        limits: CameraSidecarParserLimits
    ) -> CameraMetadataEvidence? {
        guard let xml = parseXML(document.data, limits: limits) else { return nil }
        if isCanonNewsContentXML(xml) {
            return CameraMetadataEvidence(
                manufacturer: "Canon",
                exactModel: nil,
                productFamily: "Canon XF/Cinema EOS workflow",
                source: .workflowSidecar,
                confidence: .low,
                isCameraNative: false,
                sourceFileName: document.sourceName
            )
        }
        let identity = explicitXMLIdentity(
            xml.nodes,
            expectedManufacturer: "Canon",
            limits: limits
        )
        if identity.isConflict {
            return conflictEvidence(
                manufacturer: "Canon",
                productFamily: "Canon XF/Cinema EOS workflow",
                isCameraNative: false,
                sourceName: document.sourceName
            )
        }
        return CameraMetadataEvidence(
            manufacturer: "Canon",
            exactModel: identity.model,
            productFamily: "Canon XF/Cinema EOS workflow",
            source: identity.model == nil ? .directorySignature : .explicitSidecarField,
            confidence: identity.model == nil ? .low : .medium,
            isCameraNative: false,
            sourceFileName: document.sourceName
        )
    }

    private static func isCanonNewsContentXML(_ xml: ParsedXML) -> Bool {
        let newsElementNames: Set<String> = [
            "newsml", "newsmlg2", "newsml2",
            "newsitem", "newsmetadata", "newsmessage"
        ]
        if newsElementNames.contains(normalizedKey(xml.rootName)) {
            return true
        }
        return xml.nodes.contains { node in
            newsElementNames.contains(normalizedKey(node.name))
        }
    }

    private static func parseREDRMD(
        _ document: CameraSidecarDocument,
        limits: CameraSidecarParserLimits
    ) -> CameraMetadataEvidence? {
        guard !document.data.isEmpty else { return nil }
        guard let identity = explicitIdentity(
            in: document.data,
            expectedManufacturer: "RED",
            limits: limits
        ) else { return nil }
        _ = identity
        return CameraMetadataEvidence(
            manufacturer: "RED",
            exactModel: nil,
            productFamily: "RED R3D workflow",
            source: .workflowSidecar,
            confidence: .low,
            isCameraNative: false,
            sourceFileName: document.sourceName
        )
    }

    private static func parseDJISRT(
        _ document: CameraSidecarDocument,
        limits: CameraSidecarParserLimits
    ) -> CameraMetadataEvidence? {
        guard !document.data.isEmpty,
              String(data: document.data, encoding: .utf8) != nil else { return nil }
        let identity = explicitKeyValueIdentity(
            String(decoding: document.data, as: UTF8.self),
            expectedManufacturer: "DJI",
            maxFieldLength: limits.maxFieldLength
        )
        return CameraMetadataEvidence(
            manufacturer: "DJI",
            exactModel: identity.model,
            productFamily: "DJI camera workflow",
            source: identity.model == nil ? .workflowSidecar : .explicitSidecarField,
            confidence: identity.model == nil ? .low : .medium,
            isCameraNative: true,
            sourceFileName: document.sourceName
        )
    }

    private static func parseDJIXMP(
        _ document: CameraSidecarDocument,
        limits: CameraSidecarParserLimits
    ) -> CameraMetadataEvidence? {
        guard let xml = parseXML(document.data, limits: limits) else { return nil }
        let identity = explicitXMLIdentity(
            xml.nodes,
            expectedManufacturer: "DJI",
            limits: limits
        )
        if identity.isConflict {
            return conflictEvidence(
                manufacturer: "DJI",
                productFamily: "DJI camera workflow",
                isCameraNative: false,
                sourceName: document.sourceName
            )
        }
        return CameraMetadataEvidence(
            manufacturer: "DJI",
            exactModel: identity.model,
            productFamily: "DJI camera workflow",
            source: identity.model == nil ? .workflowSidecar : .explicitSidecarField,
            confidence: identity.model == nil ? .low : .medium,
            isCameraNative: false,
            sourceFileName: document.sourceName
        )
    }

    private static func parseNikonNRAW(
        _ document: CameraSidecarDocument,
        limits: CameraSidecarParserLimits
    ) -> CameraMetadataEvidence? {
        if !document.data.isEmpty {
            _ = explicitIdentity(
                in: document.data,
                expectedManufacturer: "Nikon",
                limits: limits
            )
        }
        return CameraMetadataEvidence(
            manufacturer: "Nikon",
            exactModel: nil,
            productFamily: "Nikon N-RAW",
            source: document.data.isEmpty ? .directorySignature : .workflowSidecar,
            confidence: .low,
            isCameraNative: document.data.isEmpty,
            sourceFileName: document.sourceName
        )
    }

    private static func parseBlackmagicBRAWJSON(
        _ document: CameraSidecarDocument,
        limits: CameraSidecarParserLimits
    ) -> CameraMetadataEvidence? {
        guard !document.data.isEmpty,
              (try? JSONSerialization.jsonObject(with: document.data)) != nil else { return nil }
        return CameraMetadataEvidence(
            manufacturer: "Blackmagic Design",
            exactModel: nil,
            productFamily: "Blackmagic RAW",
            source: .workflowSidecar,
            confidence: .low,
            isCameraNative: false,
            sourceFileName: document.sourceName
        )
    }

    private static func consolidate(
        _ values: [CameraMetadataEvidence],
        maxFieldLength: Int
    ) -> [CameraMetadataEvidence] {
        let grouped = Dictionary(grouping: values) { ($0.manufacturer ?? "").lowercased() }
        return grouped.keys.sorted().compactMap { key in
            guard let group = grouped[key], !group.isEmpty else { return nil }
            let exactModels = Set(group.compactMap(\.exactModel))
            let preferred = group.max { lhs, rhs in
                if lhs.confidence != rhs.confidence {
                    return confidenceRank(lhs.confidence) < confidenceRank(rhs.confidence)
                }
                return lhs.exactModel == nil && rhs.exactModel != nil
            } ?? group[0]

            if exactModels.count > 1 {
                let sourceNames = boundedValue(
                    group.compactMap(\.sourceFileName).joined(separator: ", "),
                    maxLength: maxFieldLength
                ) ?? preferred.sourceFileName ?? "multiple-sidecars"
                return conflictEvidence(
                    manufacturer: preferred.manufacturer ?? "Unknown",
                    productFamily: preferred.productFamily,
                    isCameraNative: group.allSatisfy { $0.isCameraNative },
                    sourceName: sourceNames
                )
            }
            return preferred
        }
    }

    private static func conflictEvidence(
        manufacturer: String,
        productFamily: String?,
        isCameraNative: Bool,
        sourceName: String
    ) -> CameraMetadataEvidence {
        CameraMetadataEvidence(
            manufacturer: manufacturer,
            exactModel: nil,
            productFamily: productFamily,
            source: .workflowSidecar,
            confidence: .low,
            isCameraNative: isCameraNative,
            sourceFileName: sourceName,
            attributes: ["conflict": "true"]
        )
    }

    private static func confidenceRank(_ value: CameraMetadataConfidence) -> Int {
        switch value {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }

    private struct ExplicitIdentity {
        let model: String?
        let isConflict: Bool
    }

    private struct IdentityScope {
        var manufacturers: [String] = []
        var models: [String] = []
    }

    private static func explicitIdentity(
        in data: Data,
        expectedManufacturer: String,
        limits: CameraSidecarParserLimits
    ) -> ExplicitIdentity? {
        let text = String(decoding: data, as: UTF8.self)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<") {
            guard let xml = parseXML(data, limits: limits) else { return nil }
            return explicitXMLIdentity(
                xml.nodes,
                expectedManufacturer: expectedManufacturer,
                limits: limits
            )
        }
        if let object = try? JSONSerialization.jsonObject(with: data) {
            return explicitJSONIdentity(
                object,
                expectedManufacturer: expectedManufacturer,
                limits: limits
            )
        }
        return explicitKeyValueIdentity(
            text,
            expectedManufacturer: expectedManufacturer,
            maxFieldLength: limits.maxFieldLength
        )
    }

    private static func explicitXMLIdentity(
        _ nodes: [XMLNode],
        expectedManufacturer: String,
        limits: CameraSidecarParserLimits
    ) -> ExplicitIdentity {
        var scopes: [String: IdentityScope] = [:]
        for node in nodes {
            if isCameraIdentityPath(node.path) {
                let scopeKey = node.path.joined(separator: "/")
                var scope = scopes[scopeKey] ?? IdentityScope()
                for (key, rawValue) in node.attributes {
                    guard let value = boundedValue(rawValue, maxLength: limits.maxFieldLength) else { continue }
                    let normalized = normalizedKey(key)
                    if manufacturerKeys.contains(normalized) {
                        scope.manufacturers.append(value)
                    } else if modelKeys.contains(normalized) {
                        scope.models.append(value)
                    }
                }
                scopes[scopeKey] = scope
            }

            let normalizedName = normalizedKey(node.name)
            guard manufacturerKeys.contains(normalizedName) || modelKeys.contains(normalizedName) else { continue }
            let parentPath = Array(node.path.dropLast())
            guard isCameraIdentityPath(parentPath),
                  let value = boundedValue(node.text, maxLength: limits.maxFieldLength) else { continue }
            let parentKey = parentPath.joined(separator: "/")
            var parentScope = scopes[parentKey] ?? IdentityScope()
            if manufacturerKeys.contains(normalizedName) {
                parentScope.manufacturers.append(value)
            } else {
                parentScope.models.append(value)
            }
            scopes[parentKey] = parentScope
        }

        var matchingModels = Set<String>()
        for scope in scopes.values
            where scope.manufacturers.contains(where: { containsToken($0, expectedManufacturer) }) {
            matchingModels.formUnion(scope.models)
        }
        return ExplicitIdentity(
            model: matchingModels.count == 1 ? matchingModels.first : nil,
            isConflict: matchingModels.count > 1
        )
    }

    private static func explicitJSONIdentity(
        _ object: Any,
        expectedManufacturer: String,
        limits: CameraSidecarParserLimits
    ) -> ExplicitIdentity? {
        var matchingModels = Set<String>()
        var visited = 0

        func visit(_ value: Any, path: [String], depth: Int) {
            guard depth <= limits.maxXMLDepth, visited < limits.maxXMLNodes else { return }
            visited += 1
            if let dictionary = value as? [String: Any] {
                var makers: [String] = []
                var models: [String] = []
                for (key, child) in dictionary {
                    let normalized = normalizedKey(key)
                    if let string = child as? String,
                       let bounded = boundedValue(string, maxLength: limits.maxFieldLength) {
                        if manufacturerKeys.contains(normalized) {
                            makers.append(bounded)
                        } else if modelKeys.contains(normalized) {
                            models.append(bounded)
                        }
                    }
                }
                if isCameraIdentityPath(path),
                   makers.contains(where: { containsToken($0, expectedManufacturer) }) {
                    matchingModels.formUnion(models)
                }
                for (key, child) in dictionary {
                    visit(child, path: path + [key], depth: depth + 1)
                }
            } else if let array = value as? [Any] {
                for child in array {
                    visit(child, path: path, depth: depth + 1)
                }
            }
        }
        visit(object, path: [], depth: 0)
        guard visited <= limits.maxXMLNodes else { return nil }
        return ExplicitIdentity(
            model: matchingModels.count == 1 ? matchingModels.first : nil,
            isConflict: matchingModels.count > 1
        )
    }

    private static func isCameraIdentityPath(_ path: [String]) -> Bool {
        !path.map(normalizedKey).contains { component in
            component.contains("lens")
                || component.contains("optic")
                || component.contains("software")
                || component.contains("creator")
                || component.contains("artist")
        }
    }

    private static func explicitKeyValueIdentity(
        _ text: String,
        expectedManufacturer: String,
        maxFieldLength: Int
    ) -> ExplicitIdentity {
        var makers: [String] = []
        var models: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let pair: [Substring]
            if line.contains("=") {
                pair = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            } else {
                pair = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            }
            guard pair.count == 2,
                  let value = boundedValue(String(pair[1]), maxLength: maxFieldLength) else { continue }
            let key = normalizedKey(String(pair[0]))
            if manufacturerKeys.contains(key) {
                makers.append(value)
            } else if modelKeys.contains(key) {
                models.append(value)
            }
        }
        let makerMatches = makers.contains { containsToken($0, expectedManufacturer) }
        let uniqueModels = Set(models)
        return ExplicitIdentity(
            model: makerMatches && uniqueModels.count == 1 ? uniqueModels.first : nil,
            isConflict: makerMatches && uniqueModels.count > 1
        )
    }

    private static let manufacturerKeys: Set<String> = [
        "manufacturer", "make", "cameramanufacturer", "devicemanufacturer"
    ]
    private static let modelKeys: Set<String> = [
        "model", "modelname", "cameramodel", "cameramodelname", "devicemodel", "devicemodelname"
    ]

    private static func firstIndex(in values: [String], matching keys: Set<String>) -> Int? {
        values.firstIndex { keys.contains($0) }
    }

    private static func value(
        at index: Int?,
        in fields: [String],
        limits: CameraSidecarParserLimits
    ) -> String? {
        guard let index, fields.indices.contains(index) else { return nil }
        return boundedValue(fields[index], maxLength: limits.maxFieldLength)
    }

    private static func normalizedKey(_ value: String) -> String {
        value.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
            .lowercased()
    }

    private static func boundedValue(_ value: String, maxLength: Int) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLength else { return nil }
        return trimmed
    }

    private static func containsToken(_ value: String?, _ token: String) -> Bool {
        value?.range(of: token, options: .caseInsensitive) != nil
    }

    private static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func isARRICameraModel(_ value: String) -> Bool {
        value.range(of: "ALEXA", options: .caseInsensitive) != nil
            || value.range(of: "AMIRA", options: .caseInsensitive) != nil
    }

    private static func normalizedARRIModel(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.uppercased().hasPrefix("ARRI ") {
            return String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private static func attributeValue(
        in node: XMLNode,
        keys: Set<String>,
        maxFieldLength: Int
    ) -> String? {
        for (key, value) in node.attributes where keys.contains(normalizedKey(key)) {
            if let bounded = boundedValue(value, maxLength: maxFieldLength) {
                return bounded
            }
        }
        return nil
    }

    private static func fieldValues(
        in nodes: [XMLNode],
        keys: Set<String>,
        maxFieldLength: Int,
        includeAttributes: Bool = false
    ) -> [String] {
        var values: [String] = []
        for node in nodes {
            if keys.contains(normalizedKey(node.name)),
               let value = boundedValue(node.text, maxLength: maxFieldLength) {
                values.append(value)
            }
            if includeAttributes {
                for (key, rawValue) in node.attributes where keys.contains(normalizedKey(key)) {
                    if let value = boundedValue(rawValue, maxLength: maxFieldLength) {
                        values.append(value)
                    }
                }
            }
        }
        return values
    }

    private struct ParsedXML {
        let rootName: String
        let nodes: [XMLNode]
    }

    fileprivate struct XMLNode {
        let name: String
        let path: [String]
        let attributes: [String: String]
        let text: String
    }

    private static func parseXML(
        _ data: Data,
        limits: CameraSidecarParserLimits
    ) -> ParsedXML? {
        guard !data.isEmpty,
              limits.maxXMLDepth > 0,
              limits.maxXMLNodes > 0 else { return nil }
        let declarationProbe = String(decoding: data, as: UTF8.self).lowercased()
        guard !declarationProbe.contains("<!doctype"),
              !declarationProbe.contains("<!entity") else { return nil }

        let collector = BoundedXMLCollector(limits: limits)
        let parser = XMLParser(data: data)
        parser.delegate = collector
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        guard parser.parse(),
              !collector.rejected,
              let rootName = collector.rootName else { return nil }
        return ParsedXML(rootName: rootName, nodes: collector.nodes)
    }
}

private final class BoundedXMLCollector: NSObject, XMLParserDelegate {
    private struct Frame {
        let name: String
        let path: [String]
        let attributes: [String: String]
        var text = ""
        var textOverflow = false
    }

    private let limits: CameraSidecarParserLimits
    private var frames: [Frame] = []
    fileprivate private(set) var rootName: String?
    fileprivate private(set) var nodes: [CameraSidecarParsers.XMLNode] = []
    fileprivate private(set) var rejected = false

    init(limits: CameraSidecarParserLimits) {
        self.limits = limits
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard !rejected else { return }
        let name = localName(elementName, qualifiedName: qName)
        if rootName == nil {
            rootName = name
        }
        guard frames.count < limits.maxXMLDepth,
              nodes.count + frames.count < limits.maxXMLNodes else {
            rejected = true
            parser.abortParsing()
            return
        }
        let boundedAttributes = attributeDict.reduce(into: [String: String]()) { result, item in
            let key = localName(item.key, qualifiedName: nil)
            let value = item.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty, value.count <= limits.maxFieldLength {
                result[key] = value
            }
        }
        frames.append(Frame(
            name: name,
            path: frames.map(\.name) + [name],
            attributes: boundedAttributes
        ))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !rejected, !frames.isEmpty else { return }
        let index = frames.count - 1
        guard !frames[index].textOverflow else { return }
        if frames[index].text.count + string.count > limits.maxFieldLength {
            frames[index].text = ""
            frames[index].textOverflow = true
        } else {
            frames[index].text.append(string)
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard !rejected, let frame = frames.popLast() else { return }
        nodes.append(CameraSidecarParsers.XMLNode(
            name: frame.name,
            path: frame.path,
            attributes: frame.attributes,
            text: frame.textOverflow ? "" : frame.text.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        rejected = true
    }

    func parser(
        _ parser: XMLParser,
        resolveExternalEntityName name: String,
        systemID: String?
    ) -> Data? {
        rejected = true
        return nil
    }

    private func localName(_ elementName: String, qualifiedName: String?) -> String {
        let candidate = elementName.isEmpty ? (qualifiedName ?? elementName) : elementName
        return candidate.split(separator: ":").last.map(String.init) ?? candidate
    }
}

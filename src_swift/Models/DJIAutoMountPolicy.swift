import Foundation

struct DJIAutoMountCandidate: Equatable, Hashable {
    let bsdNode: String
    let volumeName: String
}

enum DJIAutoMountPolicy {
    private static let recognizedNames: Set<String> = [
        "DJIMAVIC4",
        "OSMO360",
        "OSMOACTION"
    ]

    static func unmountedCandidates(from propertyList: Any) -> [DJIAutoMountCandidate] {
        var candidates: [DJIAutoMountCandidate] = []
        collectUnmountedCandidates(from: propertyList, into: &candidates)
        return Array(Set(candidates)).sorted { $0.bsdNode.localizedStandardCompare($1.bsdNode) == .orderedAscending }
    }

    static func allBSDNodes(from propertyList: Any) -> Set<String> {
        var nodes = Set<String>()
        collectBSDNodes(from: propertyList, into: &nodes)
        return nodes
    }

    static func mountedRecognizedBSDNodes(from propertyList: Any) -> Set<String> {
        var nodes = Set<String>()
        collectMountedRecognizedBSDNodes(from: propertyList, into: &nodes)
        return nodes
    }

    static func isSafeToMount(
        candidate: DJIAutoMountCandidate,
        actualBSDNode: String?,
        actualVolumeName: String?,
        mountPoint: String?,
        isInternal: Bool?,
        isRemovable: Bool?,
        isExternal: Bool?,
        busProtocol: String?,
        isAppleDiskImage: Bool
    ) -> Bool {
        guard candidate.bsdNode.range(of: #"^disk[0-9]+(s[0-9]+)?$"#, options: .regularExpression) != nil,
              actualBSDNode == candidate.bsdNode,
              let actualVolumeName,
              normalizedName(actualVolumeName) == normalizedName(candidate.volumeName),
              isRecognizedVolumeName(actualVolumeName),
              mountPoint?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
              isInternal != true,
              busProtocol?.caseInsensitiveCompare("USB") == .orderedSame,
              isAppleDiskImage == false else { return false }
        return isRemovable == true || isExternal == true
    }

    static func isRecognizedVolumeName(_ name: String) -> Bool {
        recognizedNames.contains(normalizedName(name))
    }

    private static func collectUnmountedCandidates(
        from value: Any,
        into candidates: inout [DJIAutoMountCandidate]
    ) {
        if let dictionary = value as? [String: Any] {
            if let bsdNode = dictionary["DeviceIdentifier"] as? String,
               let volumeName = dictionary["VolumeName"] as? String,
               isRecognizedVolumeName(volumeName),
               bsdNode.range(of: #"^disk[0-9]+(s[0-9]+)?$"#, options: .regularExpression) != nil {
                let mountPoint = (dictionary["MountPoint"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if mountPoint?.isEmpty != false {
                    candidates.append(DJIAutoMountCandidate(
                        bsdNode: bsdNode,
                        volumeName: volumeName
                    ))
                }
            }
            for nested in dictionary.values {
                collectUnmountedCandidates(from: nested, into: &candidates)
            }
        } else if let array = value as? [Any] {
            for nested in array {
                collectUnmountedCandidates(from: nested, into: &candidates)
            }
        }
    }

    private static func collectBSDNodes(from value: Any, into nodes: inout Set<String>) {
        if let dictionary = value as? [String: Any] {
            if let bsdNode = dictionary["DeviceIdentifier"] as? String,
               bsdNode.range(of: #"^disk[0-9]+(s[0-9]+)?$"#, options: .regularExpression) != nil {
                nodes.insert(bsdNode)
            }
            for nested in dictionary.values {
                collectBSDNodes(from: nested, into: &nodes)
            }
        } else if let array = value as? [Any] {
            for nested in array {
                collectBSDNodes(from: nested, into: &nodes)
            }
        }
    }

    private static func collectMountedRecognizedBSDNodes(
        from value: Any,
        into nodes: inout Set<String>
    ) {
        if let dictionary = value as? [String: Any] {
            if let bsdNode = dictionary["DeviceIdentifier"] as? String,
               let volumeName = dictionary["VolumeName"] as? String,
               isRecognizedVolumeName(volumeName),
               let mountPoint = dictionary["MountPoint"] as? String,
               !mountPoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                nodes.insert(bsdNode)
            }
            for nested in dictionary.values {
                collectMountedRecognizedBSDNodes(from: nested, into: &nodes)
            }
        } else if let array = value as? [Any] {
            for nested in array {
                collectMountedRecognizedBSDNodes(from: nested, into: &nodes)
            }
        }
    }

    private static func normalizedName(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}

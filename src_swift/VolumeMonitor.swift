import Foundation
import AppKit
import Combine

public class VolumeMonitor: ObservableObject {
    @Published public var volumes: [MountedVolume] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var refreshGeneration = 0
    
    public init() {
        setupSubscriptions()
        refreshVolumes()
    }
    
    private func setupSubscriptions() {
        let center = NSWorkspace.shared.notificationCenter
        
        center.publisher(for: NSWorkspace.didMountNotification)
            .sink { [weak self] _ in self?.refreshVolumes() }
            .store(in: &cancellables)
            
        center.publisher(for: NSWorkspace.didUnmountNotification)
            .sink { [weak self] _ in self?.refreshVolumes() }
            .store(in: &cancellables)
    }
    
    public func refreshVolumes() {
        refreshGeneration += 1
        let generation = refreshGeneration
        // Read filter settings from UserDefaults (AppStorage keys)
        let excludeAPFS   = UserDefaults.standard.object(forKey: "excludeAPFS")   as? Bool ?? true
        let excludeNTFS   = UserDefaults.standard.object(forKey: "excludeNTFS")   as? Bool ?? true
        let excludeUDF    = UserDefaults.standard.object(forKey: "excludeUDF")    as? Bool ?? true
        let excludeCodex  = UserDefaults.standard.object(forKey: "excludeHDECodex") as? Bool ?? true
        let customIgnores = (try? JSONDecoder().decode([String].self, from: UserDefaults.standard.data(forKey: "customIgnores") ?? Data()))
            ?? ["TIME MACHINE", "MACINTOSH HD"]
        let ignoredNames = Set(customIgnores.map(Self.normalizeName))
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsInternalKey]
            let resourceKeys = Set(keys)
            guard let urls = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else { return }
            
            var list: [MountedVolume] = []
            
            for url in urls {
                let path = url.path
                if path == "/" || path.hasPrefix("/System") || path.hasPrefix("/private") { continue }

                let resourceValues = try? url.resourceValues(forKeys: resourceKeys)
                guard let identity = Self.diskIdentity(for: path),
                      !identity.isAppleDiskImage else { continue }

                // Some CFexpress readers do not propagate Foundation's removable flag.
                // Prefer diskutil's media identity, but never admit an internal or
                // identity-unknown volume into the camera-card workflow.
                guard Self.isEligibleExternalMedia(
                    diskInternal: identity.isInternal,
                    diskRemovable: identity.isRemovableMedia,
                    diskExternal: identity.isExternalDevice,
                    foundationRemovable: resourceValues?.volumeIsRemovable,
                    foundationInternal: resourceValues?.volumeIsInternal
                ) else { continue }
                
                var fsType = "UNKNOWN"
                var stat = statfs()
                if statfs(path, &stat) == 0 {
                    fsType = withUnsafePointer(to: &stat.f_fstypename) {
                        $0.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) {
                            String(cString: $0).uppercased()
                        }
                    }
                }
                
                // Always exclude network/system virtual types
                if ["SMBFS", "AUTOFS", "DEVFS"].contains(fsType) || fsType.hasPrefix("FDEV") { continue }
                
                // User-configurable exclusions
                if excludeAPFS  && fsType == "APFS"  { continue }
                if excludeNTFS  && fsType == "NTFS"  { continue }
                if excludeUDF   && fsType == "UDF"   { continue }
                
                let name = Self.resolvedVolumeName(
                    diskVolumeName: identity.volumeName,
                    mountURL: url
                )
                let upperName = name.uppercased()
                if ignoredNames.contains(Self.normalizeName(name)) { continue }
                
                // Exclude Codex HDE volumes if setting enabled
                if excludeCodex && (upperName.hasPrefix("CODEX") || upperName.hasPrefix("X2X")) { continue }
                
                let isGeneric = MountedVolume.genericNames.contains(upperName)
                
                var freeBytes: Int64 = 0
                var totalBytes: Int64 = 0
                guard let volumeUUID = identity.volumeUUID,
                      !volumeUUID.isEmpty else { continue }
                
                if let attrs = try? fm.attributesOfFileSystem(forPath: path) {
                    freeBytes = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
                    totalBytes = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
                }
                
                let vol = MountedVolume(
                    name: name,
                    originalName: name,
                    path: path,
                    bsdNode: identity.bsdNode,
                    volumeUUID: volumeUUID,
                    mediaUUID: identity.mediaUUID,
                    isRemovable: true,
                    isInternal: false,
                    freeBytes: freeBytes,
                    totalBytes: totalBytes,
                    isGenericName: isGeneric,
                    fileSystem: fsType
                )
                list.append(vol)
            }
            
            DispatchQueue.main.async {
                guard generation == self.refreshGeneration else { return }
                self.volumes = list
            }
        }
    }

    private struct DiskIdentity {
        let bsdNode: String
        let volumeUUID: String?
        let mediaUUID: String?
        let volumeName: String?
        let mediaName: String?
        let busProtocol: String?
        let isInternal: Bool?
        let isRemovableMedia: Bool?
        let isExternalDevice: Bool?

        var isAppleDiskImage: Bool {
            mediaName?.caseInsensitiveCompare("Apple Disk Image Media") == .orderedSame
                || busProtocol?.caseInsensitiveCompare("Disk Image") == .orderedSame
        }
    }

    private static func normalizeName(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.uppercased()
    }

    static func isEligibleExternalMedia(
        diskInternal: Bool?,
        diskRemovable: Bool?,
        diskExternal: Bool?,
        foundationRemovable: Bool?,
        foundationInternal: Bool?
    ) -> Bool {
        guard diskInternal != true, foundationInternal != true else { return false }
        return diskRemovable == true || diskExternal == true || foundationRemovable == true
    }

    static func resolvedVolumeName(diskVolumeName: String?, mountURL: URL) -> String {
        let trimmed = diskVolumeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? mountURL.lastPathComponent : trimmed
    }

    private static func diskIdentity(for path: String) -> DiskIdentity? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "-plist", path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let plist = try? PropertyListSerialization.propertyList(
                  from: output.fileHandleForReading.readDataToEndOfFile(),
                  options: [],
                  format: nil
              ) as? [String: Any],
              let bsdNode = plist["DeviceIdentifier"] as? String,
              bsdNode.hasPrefix("disk") else { return nil }

        return DiskIdentity(
            bsdNode: bsdNode,
            volumeUUID: plist["VolumeUUID"] as? String,
            mediaUUID: plist["MediaUUID"] as? String,
            volumeName: plist["VolumeName"] as? String,
            mediaName: plist["MediaName"] as? String,
            busProtocol: plist["BusProtocol"] as? String,
            isInternal: plist["Internal"] as? Bool,
            isRemovableMedia: (plist["RemovableMedia"] as? Bool) ?? (plist["Removable"] as? Bool),
            isExternalDevice: plist["RemovableMediaOrExternalDevice"] as? Bool
        )
    }
}

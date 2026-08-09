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
                // The app is for camera cards. Unknown media identity is a hard stop,
                // because scanning a backup volume is more dangerous than hiding it.
                guard resourceValues?.volumeIsRemovable == true,
                      resourceValues?.volumeIsInternal != true else { continue }

                guard let identity = Self.diskIdentity(for: path),
                      !identity.isAppleDiskImage else { continue }
                
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
                
                let name = url.lastPathComponent
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
        let mediaName: String?
        let busProtocol: String?

        var isAppleDiskImage: Bool {
            mediaName?.caseInsensitiveCompare("Apple Disk Image Media") == .orderedSame
                || busProtocol?.caseInsensitiveCompare("Disk Image") == .orderedSame
        }
    }

    private static func normalizeName(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.uppercased()
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
            mediaName: plist["MediaName"] as? String,
            busProtocol: plist["BusProtocol"] as? String
        )
    }
}

import Foundation
import AppKit
import Combine

public class VolumeMonitor: ObservableObject {
    @Published public var volumes: [MountedVolume] = []
    
    private var cancellables = Set<AnyCancellable>()
    
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
        // Read filter settings from UserDefaults (AppStorage keys)
        let excludeAPFS   = UserDefaults.standard.object(forKey: "excludeAPFS")   as? Bool ?? true
        let excludeNTFS   = UserDefaults.standard.object(forKey: "excludeNTFS")   as? Bool ?? true
        let excludeUDF    = UserDefaults.standard.object(forKey: "excludeUDF")    as? Bool ?? true
        let excludeCodex  = UserDefaults.standard.object(forKey: "excludeHDECodex") as? Bool ?? true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsInternalKey]
            guard let urls = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else { return }
            
            var list: [MountedVolume] = []
            
            for url in urls {
                let path = url.path
                if path == "/" || path.hasPrefix("/System") || path.hasPrefix("/private") { continue }
                
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
                
                // Exclude Codex HDE volumes if setting enabled
                if excludeCodex && (upperName.hasPrefix("CODEX") || upperName.hasPrefix("X2X")) { continue }
                
                let isGeneric = MountedVolume.genericNames.contains(upperName)
                
                var freeBytes: Int64 = 0
                var totalBytes: Int64 = 0
                var bsdNode = "diskXsY"
                
                if let attrs = try? fm.attributesOfFileSystem(forPath: path) {
                    freeBytes = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
                    totalBytes = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
                }
                
                // Get BSD Node name using Statfs / URL
                if let bsdName = try? url.resourceValues(forKeys: [URLResourceKey("NSURLVolumeBSDNameKey")]).allValues[URLResourceKey("NSURLVolumeBSDNameKey")] as? String {
                    bsdNode = bsdName
                } else {
                    // Fallback using diskutil info
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
                    process.arguments = ["info", "-plist", path]
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    try? process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                       let node = plist["DeviceIdentifier"] as? String {
                        bsdNode = node
                    }
                }
                
                let vol = MountedVolume(
                    name: name,
                    originalName: name,
                    path: path,
                    bsdNode: bsdNode,
                    freeBytes: freeBytes,
                    totalBytes: totalBytes,
                    isGenericName: isGeneric,
                    fileSystem: fsType
                )
                list.append(vol)
            }
            
            DispatchQueue.main.async {
                self.volumes = list
                let activeNodes = Set(list.map { $0.bsdNode })
                MainDetailView.autoRenamedSessionNodes.formIntersection(activeNodes)
            }
        }
    }
}

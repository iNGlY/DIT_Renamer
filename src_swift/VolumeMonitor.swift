import Foundation
import AppKit
import Combine

@MainActor
public class VolumeMonitor: ObservableObject {
    @Published public var volumes: [MountedVolume] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var refreshGeneration = 0
    private var refreshWorkItem: DispatchWorkItem?
    private var mountSessionIDsByPath: [String: String] = [:]
    
    public init() {
        setupSubscriptions()
        refreshVolumes()
    }
    
    private func setupSubscriptions() {
        let center = NSWorkspace.shared.notificationCenter
        
        center.publisher(for: NSWorkspace.didMountNotification)
            .sink { [weak self] notification in
                self?.recordMountEvent(notification, isMounted: true)
            }
            .store(in: &cancellables)
            
        center.publisher(for: NSWorkspace.didUnmountNotification)
            .sink { [weak self] notification in
                self?.recordMountEvent(notification, isMounted: false)
            }
            .store(in: &cancellables)
    }

    private func recordMountEvent(_ notification: Notification, isMounted: Bool) {
        if let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
            if isMounted {
                mountSessionIDsByPath[url.path] = UUID().uuidString
            } else {
                mountSessionIDsByPath.removeValue(forKey: url.path)
            }
        }
        scheduleRefresh()
    }

    private func scheduleRefresh() {
        refreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.refreshVolumes() }
        refreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
    
    public func refreshVolumes(completion: (([MountedVolume]) -> Void)? = nil) {
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
            let mountedPaths = Set(urls.map(\.path))
            
            var discovered: [(MountedVolume, String)] = []
            
            for url in urls {
                let path = url.path
                if path == "/" || path.hasPrefix("/System") || path.hasPrefix("/private") { continue }

                let resourceValues = try? url.resourceValues(forKeys: resourceKeys)
                var fsType = "UNKNOWN"
                var stat = statfs()
                if statfs(path, &stat) == 0 {
                    fsType = withUnsafePointer(to: &stat.f_fstypename) {
                        $0.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) {
                            String(cString: $0).uppercased()
                        }
                    }
                }

                let isCodexCompanion = Self.isCodexHDECompanion(
                    path: path,
                    fileSystem: fsType,
                    mountedPaths: mountedPaths
                )
                let identity = Self.diskIdentity(for: path)
                let accessLevel = Self.accessLevel(
                    volumeUUID: identity?.volumeUUID,
                    hasDiskIdentity: identity != nil,
                    isCodexCompanion: isCodexCompanion
                )
                guard let accessLevel else { continue }

                var effectiveIdentity = identity
                if isCodexCompanion {
                    guard !excludeCodex,
                          let basePath = Self.codexBasePath(forCompanionPath: path),
                          let baseIdentity = Self.diskIdentity(for: basePath),
                          !baseIdentity.isAppleDiskImage else { continue }
                    let baseURL = URL(fileURLWithPath: basePath)
                    let baseValues = try? baseURL.resourceValues(forKeys: resourceKeys)
                    guard Self.isEligibleExternalMedia(
                        diskInternal: baseIdentity.isInternal,
                        diskRemovable: baseIdentity.isRemovableMedia,
                        diskExternal: baseIdentity.isExternalDevice,
                        foundationRemovable: baseValues?.volumeIsRemovable,
                        foundationInternal: baseValues?.volumeIsInternal
                    ) else { continue }
                    effectiveIdentity = baseIdentity
                } else {
                    guard let identity, !identity.isAppleDiskImage else { continue }

                    // Some CFexpress readers do not propagate Foundation's removable flag.
                    // Prefer diskutil's media identity, but never admit an internal or
                    // identity-unknown physical volume into the camera-card workflow.
                    guard Self.isEligibleExternalMedia(
                        diskInternal: identity.isInternal,
                        diskRemovable: identity.isRemovableMedia,
                        diskExternal: identity.isExternalDevice,
                        foundationRemovable: resourceValues?.volumeIsRemovable,
                        foundationInternal: resourceValues?.volumeIsInternal
                    ) else { continue }
                }

                guard let effectiveIdentity else { continue }
                
                // Always exclude network/system virtual types
                if ["SMBFS", "AUTOFS", "DEVFS"].contains(fsType) || fsType.hasPrefix("FDEV") { continue }
                
                // User-configurable exclusions
                if excludeAPFS  && fsType == "APFS"  { continue }
                if excludeNTFS  && fsType == "NTFS"  { continue }
                if excludeUDF   && fsType == "UDF"   { continue }
                
                let name = Self.resolvedVolumeName(
                    diskVolumeName: identity?.volumeName ?? resourceValues?.volumeName,
                    mountURL: url
                )
                let upperName = name.uppercased()
                if ignoredNames.contains(Self.normalizeName(name)) { continue }
                
                // Exclude Codex HDE volumes if setting enabled
                if excludeCodex && (isCodexCompanion || upperName.hasPrefix("CODEX") || upperName.hasPrefix("X2X")) { continue }
                
                let isGeneric = MountedVolume.genericNames.contains(upperName)
                
                var freeBytes: Int64 = 0
                var totalBytes: Int64 = 0
                
                if let attrs = try? fm.attributesOfFileSystem(forPath: path) {
                    freeBytes = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
                    totalBytes = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
                }
                
                let vol = MountedVolume(
                    name: name,
                    originalName: name,
                    path: path,
                    bsdNode: effectiveIdentity.bsdNode,
                    volumeUUID: isCodexCompanion ? nil : identity?.volumeUUID,
                    mediaUUID: effectiveIdentity.mediaUUID,
                    isRemovable: true,
                    isInternal: false,
                    freeBytes: freeBytes,
                    totalBytes: totalBytes,
                    isGenericName: isGeneric,
                    fileSystem: fsType,
                    accessLevel: accessLevel,
                    isReadOnly: isCodexCompanion || effectiveIdentity.isWritable == false
                )
                discovered.append((vol, path))
            }
            
            DispatchQueue.main.async {
                guard generation == self.refreshGeneration else { return }
                let activePaths = Set(discovered.map(\.1))
                self.mountSessionIDsByPath = self.mountSessionIDsByPath.filter { activePaths.contains($0.key) }
                self.volumes = discovered.map { volume, path in
                    let sessionID = self.mountSessionIDsByPath[path] ?? UUID().uuidString
                    self.mountSessionIDsByPath[path] = sessionID
                    return MountedVolume(
                        name: volume.name,
                        originalName: volume.originalName,
                        path: volume.path,
                        bsdNode: volume.bsdNode,
                        volumeUUID: volume.volumeUUID,
                        mediaUUID: volume.mediaUUID,
                        mountSessionID: sessionID,
                        isRemovable: volume.isRemovable,
                        isInternal: volume.isInternal,
                        freeBytes: volume.freeBytes,
                        totalBytes: volume.totalBytes,
                        isGenericName: volume.isGenericName,
                        fileSystem: volume.fileSystem,
                        accessLevel: volume.accessLevel,
                        isReadOnly: volume.isReadOnly
                    )
                }
                completion?(self.volumes)
            }
        }
    }

    private nonisolated struct DiskIdentity {
        let bsdNode: String
        let volumeUUID: String?
        let mediaUUID: String?
        let volumeName: String?
        let mediaName: String?
        let busProtocol: String?
        let isInternal: Bool?
        let isRemovableMedia: Bool?
        let isExternalDevice: Bool?
        let isWritable: Bool?

        var isAppleDiskImage: Bool {
            mediaName?.caseInsensitiveCompare("Apple Disk Image Media") == .orderedSame
                || busProtocol?.caseInsensitiveCompare("Disk Image") == .orderedSame
        }
    }

    private nonisolated static func normalizeName(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.uppercased()
    }

    nonisolated static func isEligibleExternalMedia(
        diskInternal: Bool?,
        diskRemovable: Bool?,
        diskExternal: Bool?,
        foundationRemovable: Bool?,
        foundationInternal: Bool?
    ) -> Bool {
        guard diskInternal != true, foundationInternal != true else { return false }
        return diskRemovable == true || diskExternal == true || foundationRemovable == true
    }

    nonisolated static func resolvedVolumeName(diskVolumeName: String?, mountURL: URL) -> String {
        let trimmed = diskVolumeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? mountURL.lastPathComponent : trimmed
    }

    nonisolated static func accessLevel(
        volumeUUID: String?,
        hasDiskIdentity: Bool,
        isCodexCompanion: Bool
    ) -> MountedVolumeAccessLevel? {
        if isCodexCompanion { return .codexCompanionReadOnly }
        guard hasDiskIdentity else { return nil }
        let uuid = volumeUUID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return uuid.isEmpty ? .inspectionOnly : .renameCapable
    }

    nonisolated static func isCodexHDECompanion(
        path: String,
        fileSystem: String,
        mountedPaths: Set<String>
    ) -> Bool {
        guard fileSystem.uppercased() == "X2XFUSE",
              let basePath = codexBasePath(forCompanionPath: path) else { return false }
        return mountedPaths.contains(basePath)
    }

    private nonisolated static func codexBasePath(forCompanionPath path: String) -> String? {
        guard path.lowercased().hasSuffix("_hde"), path.count > 4 else { return nil }
        return String(path.dropLast(4))
    }

    private nonisolated static func diskIdentity(for path: String) -> DiskIdentity? {
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
            isExternalDevice: plist["RemovableMediaOrExternalDevice"] as? Bool,
            isWritable: (plist["WritableVolume"] as? Bool) ?? (plist["Writable"] as? Bool)
        )
    }
}

import Darwin
import Foundation

struct DJIAutoMountDiskInfo {
    let bsdNode: String?
    let volumeName: String?
    let mountPoint: String?
    let isInternal: Bool?
    let isRemovable: Bool?
    let isExternal: Bool?
    let mediaName: String?
    let busProtocol: String?

    var isAppleDiskImage: Bool {
        mediaName?.caseInsensitiveCompare("Apple Disk Image Media") == .orderedSame
            || busProtocol?.caseInsensitiveCompare("Disk Image") == .orderedSame
    }
}

protocol DJIAutoMountCommandRunning: AnyObject {
    func diskListPropertyList() -> Any?
    func diskInfo(for bsdNode: String) -> DJIAutoMountDiskInfo?
    func mount(bsdNode: String) -> Bool
}

struct DJIAutoMountResult {
    let mountedBSDNodes: [String]
    let shouldRetry: Bool
}

final class DJIAutoMounter {
    static let shared = DJIAutoMounter(commandRunner: DiskUtilDJIAutoMountCommandRunner())

    private let commandRunner: DJIAutoMountCommandRunning
    private let maximumAttempts: Int
    private let lock = NSLock()
    private var attemptCounts: [String: Int] = [:]
    private var completedBSDNodes = Set<String>()
    private var diskListFailureCount = 0

    init(commandRunner: DJIAutoMountCommandRunning, maximumAttempts: Int = 3) {
        self.commandRunner = commandRunner
        self.maximumAttempts = max(1, maximumAttempts)
    }

    func mountRecognizedVolumes(isEnabled: Bool = true) -> DJIAutoMountResult {
        mountRecognizedVolumes { isEnabled }
    }

    func mountRecognizedVolumes(isEnabled: () -> Bool) -> DJIAutoMountResult {
        guard isEnabled() else {
            return DJIAutoMountResult(mountedBSDNodes: [], shouldRetry: false)
        }
        lock.lock()
        defer { lock.unlock() }

        guard let propertyList = commandRunner.diskListPropertyList() else {
            diskListFailureCount += 1
            return DJIAutoMountResult(
                mountedBSDNodes: [],
                shouldRetry: diskListFailureCount < maximumAttempts
            )
        }
        diskListFailureCount = 0
        let candidates = DJIAutoMountPolicy.unmountedCandidates(from: propertyList)
        let attachedNodes = DJIAutoMountPolicy.allBSDNodes(from: propertyList)
        attemptCounts = attemptCounts.filter { attachedNodes.contains($0.key) }
        completedBSDNodes = completedBSDNodes.intersection(attachedNodes)
        completedBSDNodes.formUnion(DJIAutoMountPolicy.mountedRecognizedBSDNodes(from: propertyList))

        var mountedNodes: [String] = []
        var shouldRetry = false
        for candidate in candidates {
            guard isEnabled() else {
                return DJIAutoMountResult(mountedBSDNodes: mountedNodes, shouldRetry: false)
            }
            guard !completedBSDNodes.contains(candidate.bsdNode) else { continue }
            let attempts = attemptCounts[candidate.bsdNode, default: 0]
            guard attempts < maximumAttempts else { continue }

            guard let info = commandRunner.diskInfo(for: candidate.bsdNode) else {
                attemptCounts[candidate.bsdNode] = attempts + 1
                shouldRetry = shouldRetry || attempts + 1 < maximumAttempts
                continue
            }

            let terminalMismatch = info.bsdNode != candidate.bsdNode
                || info.volumeName.map { !DJIAutoMountPolicy.isRecognizedVolumeName($0) } == true
                || info.mountPoint?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                || info.isInternal == true
                || info.busProtocol.map { $0.caseInsensitiveCompare("USB") != .orderedSame } == true
                || info.isAppleDiskImage
            if terminalMismatch {
                completedBSDNodes.insert(candidate.bsdNode)
                continue
            }

            guard info.volumeName != nil,
                  info.busProtocol != nil,
                  info.isRemovable == true || info.isExternal == true else {
                attemptCounts[candidate.bsdNode] = attempts + 1
                shouldRetry = shouldRetry || attempts + 1 < maximumAttempts
                continue
            }
            guard DJIAutoMountPolicy.isSafeToMount(
                candidate: candidate,
                actualBSDNode: info.bsdNode,
                actualVolumeName: info.volumeName,
                mountPoint: info.mountPoint,
                isInternal: info.isInternal,
                isRemovable: info.isRemovable,
                isExternal: info.isExternal,
                busProtocol: info.busProtocol,
                isAppleDiskImage: info.isAppleDiskImage
            ) else {
                completedBSDNodes.insert(candidate.bsdNode)
                continue
            }

            attemptCounts[candidate.bsdNode] = attempts + 1
            guard isEnabled() else {
                return DJIAutoMountResult(mountedBSDNodes: mountedNodes, shouldRetry: false)
            }
            if commandRunner.mount(bsdNode: candidate.bsdNode) {
                completedBSDNodes.insert(candidate.bsdNode)
                mountedNodes.append(candidate.bsdNode)
            } else if attempts + 1 < maximumAttempts {
                shouldRetry = true
            }
        }
        return DJIAutoMountResult(mountedBSDNodes: mountedNodes, shouldRetry: shouldRetry)
    }

    func markDiskDisconnected(bsdNode: String) {
        lock.lock()
        attemptCounts = attemptCounts.filter { node, _ in
            node != bsdNode && !node.hasPrefix("\(bsdNode)s")
        }
        completedBSDNodes = completedBSDNodes.filter { node in
            node != bsdNode && !node.hasPrefix("\(bsdNode)s")
        }
        lock.unlock()
    }

    func resetDiscoveryFailures() {
        lock.lock()
        diskListFailureCount = 0
        lock.unlock()
    }
}

private final class DiskUtilDJIAutoMountCommandRunner: DJIAutoMountCommandRunning {
    private struct CommandResult {
        let status: Int32
        let standardOutput: Data
    }

    func diskListPropertyList() -> Any? {
        guard let result = run(arguments: ["list", "-plist"]), result.status == 0 else { return nil }
        return try? PropertyListSerialization.propertyList(
            from: result.standardOutput,
            options: [],
            format: nil
        )
    }

    func diskInfo(for bsdNode: String) -> DJIAutoMountDiskInfo? {
        guard let result = run(arguments: ["info", "-plist", bsdNode]),
              result.status == 0,
              let plist = try? PropertyListSerialization.propertyList(
                from: result.standardOutput,
                options: [],
                format: nil
              ) as? [String: Any] else { return nil }
        return DJIAutoMountDiskInfo(
            bsdNode: plist["DeviceIdentifier"] as? String,
            volumeName: plist["VolumeName"] as? String,
            mountPoint: plist["MountPoint"] as? String,
            isInternal: plist["Internal"] as? Bool,
            isRemovable: (plist["RemovableMedia"] as? Bool) ?? (plist["Removable"] as? Bool),
            isExternal: plist["RemovableMediaOrExternalDevice"] as? Bool,
            mediaName: plist["MediaName"] as? String,
            busProtocol: plist["BusProtocol"] as? String
        )
    }

    func mount(bsdNode: String) -> Bool {
        run(arguments: ["mount", bsdNode])?.status == 0
    }

    private func run(arguments: [String], timeout: TimeInterval = 20) -> CommandResult? {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        let completion = DispatchSemaphore(value: 0)
        let readers = DispatchGroup()
        let dataLock = NSLock()
        var outputData = Data()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        process.terminationHandler = { _ in completion.signal() }

        guard (try? process.run()) != nil else { return nil }
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = standardOutput.fileHandleForReading.readDataToEndOfFile()
            dataLock.lock()
            outputData = data
            dataLock.unlock()
            readers.leave()
        }
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            _ = standardError.fileHandleForReading.readDataToEndOfFile()
            readers.leave()
        }

        guard completion.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            if completion.wait(timeout: .now() + 1) != .success {
                Darwin.kill(process.processIdentifier, SIGKILL)
                guard completion.wait(timeout: .now() + 2) == .success else {
                    try? standardOutput.fileHandleForReading.close()
                    try? standardError.fileHandleForReading.close()
                    _ = readers.wait(timeout: .now() + 2)
                    return nil
                }
            }
            _ = readers.wait(timeout: .now() + 2)
            return nil
        }
        guard readers.wait(timeout: .now() + 2) == .success else { return nil }
        dataLock.lock()
        let capturedOutput = outputData
        dataLock.unlock()
        return CommandResult(status: process.terminationStatus, standardOutput: capturedOutput)
    }
}

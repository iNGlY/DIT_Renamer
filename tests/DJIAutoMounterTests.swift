import Foundation

private final class FakeDJIAutoMountRunner: DJIAutoMountCommandRunning {
    var list: Any?
    var infoByNode: [String: DJIAutoMountDiskInfo]
    var mountResults: [String: Bool]
    private(set) var listCalls = 0
    private(set) var mountCalls: [String] = []

    init(
        list: Any,
        infoByNode: [String: DJIAutoMountDiskInfo],
        mountResults: [String: Bool]
    ) {
        self.list = list
        self.infoByNode = infoByNode
        self.mountResults = mountResults
    }

    func diskListPropertyList() -> Any? {
        listCalls += 1
        return list
    }
    func diskInfo(for bsdNode: String) -> DJIAutoMountDiskInfo? { infoByNode[bsdNode] }
    func mount(bsdNode: String) -> Bool {
        mountCalls.append(bsdNode)
        return mountResults[bsdNode] ?? false
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct DJIAutoMounterTests {
    static func main() {
        let list: [String: Any] = [
            "AllDisksAndPartitions": [
                ["DeviceIdentifier": "disk12s1", "VolumeName": "DJI Mavic4"],
                ["DeviceIdentifier": "disk13s1", "VolumeName": "Osmo360"],
                ["DeviceIdentifier": "disk14s1", "VolumeName": "Osmo Action"]
            ]
        ]
        let runner = FakeDJIAutoMountRunner(
            list: list,
            infoByNode: [
                "disk12s1": DJIAutoMountDiskInfo(
                    bsdNode: "disk12s1", volumeName: "DJI Mavic4", mountPoint: nil,
                    isInternal: false, isRemovable: nil, isExternal: true,
                    mediaName: "DJI Device Media", busProtocol: "USB"
                ),
                "disk13s1": DJIAutoMountDiskInfo(
                    bsdNode: "disk13s1", volumeName: "Osmo360", mountPoint: nil,
                    isInternal: true, isRemovable: true, isExternal: true,
                    mediaName: "Internal Test Media", busProtocol: "USB"
                ),
                "disk14s1": DJIAutoMountDiskInfo(
                    bsdNode: "disk14s1", volumeName: "Osmo Action", mountPoint: nil,
                    isInternal: false, isRemovable: nil, isExternal: nil,
                    mediaName: "Identity Pending", busProtocol: "USB"
                )
            ],
            mountResults: ["disk12s1": true]
        )
        let mounter = DJIAutoMounter(commandRunner: runner, maximumAttempts: 3)

        let disabled = mounter.mountRecognizedVolumes(isEnabled: false)
        require(disabled.mountedBSDNodes.isEmpty && !disabled.shouldRetry, "A disabled DJI option must stay idle")
        require(runner.listCalls == 0, "Disabling DJI auto-mount must avoid even the disk inventory command")

        var enablementChecks = 0
        let cancelledDuringRefresh = mounter.mountRecognizedVolumes {
            enablementChecks += 1
            return enablementChecks < 3
        }
        require(cancelledDuringRefresh.mountedBSDNodes.isEmpty, "Turning the option off during refresh must cancel mounting")
        require(runner.mountCalls.isEmpty, "The option must be checked again immediately before issuing a mount command")

        let first = mounter.mountRecognizedVolumes()
        require(first.mountedBSDNodes == ["disk12s1"], "The verified external Mavic 4 volume should mount")
        require(runner.mountCalls == ["disk12s1"], "Unsafe or identity-unknown devices must not receive a mount command")
        require(first.shouldRetry, "A temporarily identity-unknown recognized DJI volume should request a bounded retry")

        _ = mounter.mountRecognizedVolumes()
        _ = mounter.mountRecognizedVolumes()
        let fourth = mounter.mountRecognizedVolumes()
        require(runner.mountCalls == ["disk12s1"], "A successfully mounted BSD node must not be mounted twice from a stale disk list")
        require(!fourth.shouldRetry, "Retries must stop after the configured maximum instead of creating a scan loop")

        runner.list = [
            "AllDisksAndPartitions": [
                [
                    "DeviceIdentifier": "disk12s1",
                    "VolumeName": "DJI Mavic4",
                    "MountPoint": "/Volumes/DJI Mavic4"
                ]
            ]
        ]
        _ = mounter.mountRecognizedVolumes()
        runner.list = list
        _ = mounter.mountRecognizedVolumes()
        require(
            runner.mountCalls == ["disk12s1"],
            "A user-unmounted DJI volume must not be mounted again until its BSD node disappears and a new connection begins"
        )

        mounter.markDiskDisconnected(bsdNode: "disk12")
        _ = mounter.mountRecognizedVolumes()
        require(
            runner.mountCalls == ["disk12s1", "disk12s1"],
            "A physical disconnect must reset the bounded state so a new connection may auto-mount even when macOS reuses the BSD node"
        )

        let unavailableRunner = FakeDJIAutoMountRunner(list: [:], infoByNode: [:], mountResults: [:])
        unavailableRunner.list = nil
        let unavailableMounter = DJIAutoMounter(commandRunner: unavailableRunner, maximumAttempts: 3)
        require(unavailableMounter.mountRecognizedVolumes().shouldRetry, "The first disk-list failure should retry")
        require(unavailableMounter.mountRecognizedVolumes().shouldRetry, "The second disk-list failure should retry")
        require(!unavailableMounter.mountRecognizedVolumes().shouldRetry, "Disk-list retries must stop at the configured maximum")
        require(!unavailableMounter.mountRecognizedVolumes().shouldRetry, "A failed disk list must not create an unbounded refresh loop")
        unavailableMounter.resetDiscoveryFailures()
        require(
            unavailableMounter.mountRecognizedVolumes().shouldRetry,
            "A new disk appearance or explicit user refresh must receive a fresh bounded retry budget"
        )

        let initiallyMountedRunner = FakeDJIAutoMountRunner(
            list: [
                "AllDisksAndPartitions": [[
                    "DeviceIdentifier": "disk16",
                    "VolumeName": "Osmo360",
                    "MountPoint": "/Volumes/Osmo360"
                ]]
            ],
            infoByNode: [
                "disk16": DJIAutoMountDiskInfo(
                    bsdNode: "disk16", volumeName: "Osmo360", mountPoint: nil,
                    isInternal: false, isRemovable: true, isExternal: true,
                    mediaName: "DJI Device Media", busProtocol: "USB"
                )
            ],
            mountResults: ["disk16": true]
        )
        let initiallyMountedMounter = DJIAutoMounter(commandRunner: initiallyMountedRunner)
        _ = initiallyMountedMounter.mountRecognizedVolumes()
        initiallyMountedRunner.list = [
            "AllDisksAndPartitions": [[
                "DeviceIdentifier": "disk16",
                "VolumeName": "Osmo360"
            ]]
        ]
        _ = initiallyMountedMounter.mountRecognizedVolumes()
        require(
            initiallyMountedRunner.mountCalls.isEmpty,
            "A recognized DJI volume that was already mounted must stay unmounted after the operator explicitly unmounts it"
        )

        print("DJIAutoMounterTests: PASS")
    }
}

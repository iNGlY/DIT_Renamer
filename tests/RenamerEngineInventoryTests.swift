import Foundation

@main
struct RenamerEngineInventoryTests {
    static func main() {
        let validPlist: [String: Any] = [
            "AllDisksAndPartitions": [[
                "DeviceIdentifier": "disk4",
                "Partitions": [[
                    "DeviceIdentifier": "disk4s1",
                    "MountPoint": "/Volumes/A001",
                    "VolumeName": "A001"
                ], [
                    "DeviceIdentifier": "disk4s2",
                    "VolumeName": "UNMOUNTED"
                ]]
            ]]
        ]
        let validInventory = RenamerEngine.mountedVolumeInventory(from: validPlist)
        precondition(validInventory?.count == 1)
        precondition(validInventory?.first?.bsdNode == "disk4s1")
        precondition(validInventory?.first?.name == "A001")

        let missingName: [String: Any] = [
            "AllDisksAndPartitions": [[
                "DeviceIdentifier": "disk5s1",
                "MountPoint": "/Volumes/Unknown"
            ]]
        ]
        precondition(
            RenamerEngine.mountedVolumeInventory(from: missingName) == nil,
            "A mounted record without VolumeName must fail closed"
        )

        let missingDeviceIdentifier: [String: Any] = [
            "AllDisksAndPartitions": [[
                "MountPoint": "/Volumes/A001_1",
                "VolumeName": "A001_1"
            ]]
        ]
        precondition(
            RenamerEngine.mountedVolumeInventory(from: missingDeviceIdentifier) == nil,
            "A mounted record without DeviceIdentifier must fail closed"
        )

        let invalidMountPoint: [String: Any] = [
            "AllDisksAndPartitions": [[
                "DeviceIdentifier": "disk6s1",
                "MountPoint": 42,
                "VolumeName": "A002"
            ]]
        ]
        precondition(
            RenamerEngine.mountedVolumeInventory(from: invalidMountPoint) == nil,
            "An invalid MountPoint field must fail closed"
        )

        print("RenamerEngineInventoryTests: PASS")
    }
}

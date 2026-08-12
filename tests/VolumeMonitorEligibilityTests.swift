import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct VolumeMonitorEligibilityTests {
    static func main() {
        require(
            VolumeMonitor.isEligibleExternalMedia(
                diskInternal: nil,
                diskRemovable: nil,
                diskExternal: true,
                foundationRemovable: nil,
                foundationInternal: nil
            ),
            "An explicitly external CFexpress reader must remain eligible when Internal is absent"
        )
        require(
            !VolumeMonitor.isEligibleExternalMedia(
                diskInternal: true,
                diskRemovable: true,
                diskExternal: true,
                foundationRemovable: true,
                foundationInternal: false
            ),
            "An internal disk must always be rejected"
        )
        require(
            !VolumeMonitor.isEligibleExternalMedia(
                diskInternal: nil,
                diskRemovable: nil,
                diskExternal: nil,
                foundationRemovable: nil,
                foundationInternal: nil
            ),
            "Unknown media identity must remain a hard stop"
        )
        require(
            VolumeMonitor.isEligibleExternalMedia(
                diskInternal: false,
                diskRemovable: nil,
                diskExternal: nil,
                foundationRemovable: true,
                foundationInternal: false
            ),
            "Foundation removable evidence may admit a confirmed non-internal reader"
        )
        print("VolumeMonitorEligibilityTests passed")
    }
}

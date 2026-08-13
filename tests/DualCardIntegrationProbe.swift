import Foundation

@main
struct DualCardIntegrationProbe {
    static func main() async {
        guard CommandLine.arguments.count == 9 else {
            fputs("usage: probe pathA bsdA uuidA mediaA pathB bsdB uuidB mediaB\n", stderr)
            exit(2)
        }

        let arguments = CommandLine.arguments
        let pathA = arguments[1]
        let bsdA = arguments[2]
        let uuidA = arguments[3]
        let mediaA = arguments[4] == "-" ? nil : arguments[4]
        let pathB = arguments[5]
        let bsdB = arguments[6]
        let uuidB = arguments[7]
        let mediaB = arguments[8] == "-" ? nil : arguments[8]

        precondition(bsdA != bsdB, "The simulated readers must expose different BSD nodes")
        precondition(uuidA == uuidB, "The cloned cards must expose the same Volume UUID")

        let scanA = MediaScanner.scan(volumePath: pathA)
        let scanB = MediaScanner.scan(volumePath: pathB)
        precondition(scanA.isHighConfidence && scanA.suggestedName == "A247")
        precondition(scanB.isHighConfidence && scanB.suggestedName == "B101")
        precondition(scanA.firstClipName != scanB.firstClipName)
        precondition(scanA.lastClipName != scanB.lastClipName)

        let resultA = await RenamerEngine.renameVolumeAsync(
            at: pathA,
            bsdNode: bsdA,
            volumeUUID: uuidA,
            mediaUUID: mediaA,
            fileSystem: "ExFAT",
            to: "A247"
        )
        precondition(resultA.success && resultA.actualName == "A247", resultA.message)

        let resultB = await RenamerEngine.renameVolumeAsync(
            at: pathB,
            bsdNode: bsdB,
            volumeUUID: uuidB,
            mediaUUID: mediaB,
            fileSystem: "ExFAT",
            to: "B101"
        )
        precondition(resultB.success && resultB.actualName == "B101", resultB.message)

        print("DualCardIntegrationProbe: PASS")
    }
}

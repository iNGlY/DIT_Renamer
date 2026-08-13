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
        precondition(scanA.isHighConfidence && scanA.suggestedName == "A001")
        precondition(scanB.isHighConfidence && scanB.suggestedName == "A001")
        precondition(scanA.firstClipName != scanB.firstClipName)
        precondition(scanA.lastClipName != scanB.lastClipName)

        let resultA = await RenamerEngine.renameVolumeAsync(
            at: pathA,
            bsdNode: bsdA,
            volumeUUID: uuidA,
            mediaUUID: mediaA,
            fileSystem: "ExFAT",
            to: "A001"
        )
        precondition(resultA.success && resultA.actualName == "A001", resultA.message)

        let conflictingResultB = await RenamerEngine.renameVolumeAsync(
            at: pathB,
            bsdNode: bsdB,
            volumeUUID: uuidB,
            mediaUUID: mediaB,
            fileSystem: "ExFAT",
            to: "A001"
        )
        precondition(!conflictingResultB.success, "A second mounted card must never be renamed to the already-mounted A001")

        let resolvedResultB = await RenamerEngine.renameVolumeAsync(
            at: pathB,
            bsdNode: bsdB,
            volumeUUID: uuidB,
            mediaUUID: mediaB,
            fileSystem: "ExFAT",
            to: "A001_1"
        )
        precondition(resolvedResultB.success && resolvedResultB.actualName == "A001_1", resolvedResultB.message)

        print("DualCardIntegrationProbe: PASS")
    }
}

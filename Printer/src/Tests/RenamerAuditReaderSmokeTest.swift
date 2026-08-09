import Foundation

@main
struct RenamerAuditReaderSmokeTest {
    static func main() {
        let fixture = URL(fileURLWithPath: CommandLine.arguments[1])
        guard let record = RenamerAuditReader.latestMatch(
            sourceVolumePath: "/Volumes/A001",
            auditFileURL: fixture
        ),
        record.actualName == "A001",
        record.deviceType == "Sony FX3",
        record.lastClipName == "A001C012_240101AA.MP4" else {
            fputs("Renamer audit reader fixture failed\n", stderr)
            exit(1)
        }
        print("Renamer audit reader fixture passed")
    }
}

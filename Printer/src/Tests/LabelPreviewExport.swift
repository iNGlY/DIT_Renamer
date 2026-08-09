import Foundation

@main
enum LabelPreviewExport {
    static func main() {
        guard let outputPath = CommandLine.arguments.dropFirst().first else {
            fatalError("Usage: LabelPreviewExport /absolute/output.png")
        }
        do {
            let job = DITPrinterJob(
                binName: "S01_D02_主机位",
                lastAssetName: "A001C003_260809_素材.mov",
                copyCompletedAt: Date(timeIntervalSince1970: 1_786_278_896),
                reuseCount: 3
            )
            let data = try TSPLLabelRenderer.previewPNG(job: job)
            try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        } catch {
            fatalError("Preview export failed: \(error.localizedDescription)")
        }
    }
}

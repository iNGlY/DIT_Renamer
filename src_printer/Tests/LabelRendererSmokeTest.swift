import Foundation

@main
enum LabelRendererSmokeTest {
    static func main() {
        do {
            let job = DITPrinterJob(
                binName: "S01_D02_主机位",
                lastAssetName: "A001C003_260809_素材.mov",
                copyCompletedAt: Date(timeIntervalSince1970: 1_786_278_896),
                reuseCount: 3
            )
            let label = try TSPLLabelRenderer.render(job: job)
            let header = String(data: label.prefix(80), encoding: .ascii) ?? ""
            guard header.hasPrefix("SIZE 72 mm,51 mm\r\nGAP 3 mm,0 mm\r\nDIRECTION 1\r\nCLS\r\nBITMAP 0,0,72,408,0,") else {
                fatalError("Missing expected TSPL header: \(header.debugDescription)")
            }
            let compact = LabelTemplate(id: "test-60x40", name: "60 x 40 mm", widthMm: 60, heightMm: 40, gapMm: 2)
            let compactLabel = try TSPLLabelRenderer.render(job: job, template: compact)
            let compactHeader = String(data: compactLabel.prefix(80), encoding: .ascii) ?? ""
            guard compactHeader.hasPrefix("SIZE 60 mm,40 mm\r\nGAP 2 mm,0 mm\r\nDIRECTION 1\r\nCLS\r\nBITMAP 0,0,60,320,0,") else {
                fatalError("Missing custom stock TSPL header: \(compactHeader.debugDescription)")
            }
            guard label.suffix(13) == Data("\r\nPRINT 1,1\r\n".utf8) else {
                fatalError("Missing expected TSPL print command")
            }
            let pdf = try TSPLLabelRenderer.pdfData(job: job)
            guard String(data: pdf.prefix(4), encoding: .ascii) == "%PDF" else {
                fatalError("PDF label rendering did not produce a PDF document")
            }
            print("Label renderer smoke test passed: TSPL=\(label.count), custom=\(compactLabel.count), PDF=\(pdf.count) bytes")
        } catch {
            fatalError("TSPL label smoke test failed: \(error.localizedDescription)")
        }
    }
}

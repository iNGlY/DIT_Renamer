import AppKit
import Foundation

enum CUPSPrinterError: LocalizedError {
    case noQueue
    case renderFailed
    case submissionFailed(String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .noQueue: return "Select a CUPS printer queue."
        case .renderFailed: return "DIT Printer could render the label image."
        case .submissionFailed(let reason): return reason
        case .timedOut(let command): return "\(command) did not return within 20 seconds."
        }
    }
}

enum CUPSPrinter {
    static func availableQueues() -> [String] {
        guard let output = try? run(executable: "/usr/bin/lpstat", arguments: ["-p"], timeout: 5) else { return [] }
        return output
            .split(separator: "\n")
            .compactMap { line -> String? in
                let parts = line.split(separator: " ")
                guard parts.count >= 2, parts[0] == "printer" else { return nil }
                return String(parts[1])
            }
            .sorted()
    }

    static func submit(job: DITPrinterJob, queueName: String, template: LabelTemplate) throws -> String {
        guard !queueName.isEmpty else { throw CUPSPrinterError.noQueue }
        let data = try TSPLLabelRenderer.render(job: job, template: template)
        let directory = try DITPrinterJob.jobsDirectory()
            .deletingLastPathComponent()
            .appendingPathComponent("Rendered", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(job.id.uuidString).tspl")
        try data.write(to: fileURL, options: .atomic)
        return try run(executable: "/usr/bin/lp", arguments: ["-d", queueName, "-o", "raw", fileURL.path])
    }

    private static func run(executable: String, arguments: [String], timeout: TimeInterval = 20) throws -> String {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            throw CUPSPrinterError.timedOut(URL(fileURLWithPath: executable).lastPathComponent)
        }

        let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw CUPSPrinterError.submissionFailed(stderr.isEmpty ? "CUPS submission failed." : stderr)
        }
        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TSPLLabelRenderer {
    static func render(job: DITPrinterJob, template: LabelTemplate = .defaultTemplate) throws -> Data {
        guard let representation = bitmapRepresentation(job: job, template: template) else { throw CUPSPrinterError.renderFailed }
        let bitmap = rasterize(representation: representation, template: template)
        var command = Data("\(template.tsplSize)\r\n\(template.tsplGap)\r\nDIRECTION 1\r\nCLS\r\nBITMAP 0,0,\(template.bytesPerRow),\(template.heightDots),0,".utf8)
        command.append(bitmap)
        command.append(Data("\r\nPRINT 1,1\r\n".utf8))
        return command
    }

    static func previewImage(job: DITPrinterJob, template: LabelTemplate = .defaultTemplate) throws -> NSImage {
        guard let representation = bitmapRepresentation(job: job, template: template) else {
            throw CUPSPrinterError.renderFailed
        }
        let image = NSImage(size: NSSize(width: template.widthDots, height: template.heightDots))
        image.addRepresentation(representation)
        return image
    }

    static func previewPNG(job: DITPrinterJob, template: LabelTemplate = .defaultTemplate) throws -> Data {
        guard let representation = bitmapRepresentation(job: job, template: template),
              let data = representation.representation(using: .png, properties: [:]) else {
            throw CUPSPrinterError.renderFailed
        }
        return data
    }

    private static func bitmapRepresentation(job: DITPrinterJob, template: LabelTemplate) -> NSBitmapImageRep? {
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: template.widthDots,
            pixelsHigh: template.heightDots,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: .alphaFirst,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: representation) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: template.widthDots, height: template.heightDots)).fill()
        let values = [
            ("BIN", job.binName),
            ("LAST", job.lastAssetName),
            ("COPIED", copyTime(job.copyCompletedAt)),
            ("CARD REUSE", job.reuseCount.map(String.init) ?? "(not set)")
        ]

        let labelWidth = CGFloat(template.widthDots)
        let labelHeight = CGFloat(template.heightDots)
        let horizontalMargin = max(12, min(24, labelWidth * 0.04))
        let verticalMargin = max(10, min(20, labelHeight * 0.04))
        let contentWidth = labelWidth - (horizontalMargin * 2)
        let headerFont = NSFont.boldSystemFont(ofSize: max(14, min(25, labelHeight * 0.062)))
        let footerFont = NSFont.systemFont(ofSize: max(7, min(12, labelHeight * 0.03)))
        let fieldFont = NSFont.boldSystemFont(ofSize: max(8, min(15, labelHeight * 0.037)))
        let valueFont = NSFont.systemFont(ofSize: max(10, min(22, labelHeight * 0.052)))
        let headerY = labelHeight - verticalMargin - headerFont.pointSize
        let footerY = verticalMargin
        let contentTop = headerY - 10
        let contentBottom = footerY + footerFont.pointSize + 8
        let rowHeight = max(30, (contentTop - contentBottom) / CGFloat(values.count))

        draw("DIT PRINTER  |  \(template.name)", at: CGPoint(x: horizontalMargin, y: headerY), font: headerFont, width: contentWidth)
        for (index, entry) in values.enumerated() {
            let rowTop = contentTop - (CGFloat(index) * rowHeight)
            draw(entry.0, at: CGPoint(x: horizontalMargin, y: rowTop - fieldFont.pointSize), font: fieldFont, width: contentWidth)
            draw(entry.1.isEmpty ? "(not supplied)" : entry.1, at: CGPoint(x: horizontalMargin, y: rowTop - fieldFont.pointSize - valueFont.pointSize - 5), font: valueFont, width: contentWidth)
        }
        draw("Silverstack Copy + Verify complete", at: CGPoint(x: horizontalMargin, y: footerY), font: footerFont, width: contentWidth)
        NSGraphicsContext.restoreGraphicsState()

        return representation
    }

    private static func rasterize(representation: NSBitmapImageRep, template: LabelTemplate) -> Data {
        var result = Data(capacity: template.bytesPerRow * template.heightDots)
        for y in 0..<template.heightDots {
            for byteIndex in 0..<template.bytesPerRow {
                var byte: UInt8 = 0
                for bit in 0..<8 {
                    let x = byteIndex * 8 + bit
                    let color = representation.colorAt(x: x, y: template.heightDots - 1 - y) ?? .white
                    if color.brightnessComponent < 0.60 {
                        byte |= UInt8(1 << (7 - bit))
                    }
                }
                result.append(byte)
            }
        }
        return result
    }

    private static func draw(_ value: String, at point: CGPoint, font: NSFont, width: CGFloat) {
        let fitted = fittedText(value, font: font, maxWidth: width)
        (fitted as NSString).draw(at: point, withAttributes: [
            .font: font,
            .foregroundColor: NSColor.black
        ])
    }

    private static func fittedText(_ value: String, font: NSFont, maxWidth: CGFloat) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        guard (value as NSString).size(withAttributes: attributes).width > maxWidth else { return value }
        var result = value
        while !result.isEmpty {
            result.removeLast()
            let candidate = result + "..."
            if (candidate as NSString).size(withAttributes: attributes).width <= maxWidth { return candidate }
        }
        return "..."
    }

    private static func copyTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZ"
        return formatter.string(from: date)
    }
}

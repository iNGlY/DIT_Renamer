import AppKit

private let canvasSize = NSSize(width: 1024, height: 1024)

private func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

private func drawCentered(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
    let value = NSAttributedString(string: text, attributes: attributes)
    let size = value.size()
    value.draw(at: NSPoint(
        x: rect.midX - size.width / 2,
        y: rect.midY - size.height / 2
    ))
}

private func renderIcon() -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("无法创建图标画布。")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: canvasSize).fill()

    // 深色圆角底板：保留专业工具感，同时减少原图网格造成的小尺寸噪声。
    let backgroundRect = NSRect(x: 64, y: 64, width: 896, height: 896)
    let background = roundedRect(backgroundRect, radius: 210)
    let backgroundGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.105, green: 0.135, blue: 0.205, alpha: 1),
        NSColor(calibratedRed: 0.035, green: 0.050, blue: 0.085, alpha: 1)
    ])!
    backgroundGradient.draw(in: background, angle: -52)
    NSColor(calibratedWhite: 1, alpha: 0.22).setStroke()
    background.lineWidth = 6
    background.stroke()

    // 低对比度蓝色光晕用于集中视觉焦点，不引入额外图形语义。
    let glow = NSBezierPath(ovalIn: NSRect(x: 205, y: 175, width: 614, height: 670))
    NSColor(calibratedRed: 0.03, green: 0.47, blue: 1, alpha: 0.10).setFill()
    glow.fill()

    // 摄影机存储卡主体。
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.48)
    shadow.shadowOffset = NSSize(width: 0, height: -24)
    shadow.shadowBlurRadius = 32
    shadow.set()

    let cardRect = NSRect(x: 272, y: 176, width: 480, height: 648)
    let card = roundedRect(cardRect, radius: 42)
    let cardGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.245, green: 0.270, blue: 0.325, alpha: 1),
        NSColor(calibratedRed: 0.115, green: 0.130, blue: 0.165, alpha: 1)
    ])!
    cardGradient.draw(in: card, angle: -90)

    // 卡片左上缺角是存储介质的核心轮廓特征。
    NSGraphicsContext.current?.saveGraphicsState()
    NSShadow().set()
    let notch = NSBezierPath()
    notch.move(to: NSPoint(x: 272, y: 704))
    notch.line(to: NSPoint(x: 392, y: 824))
    notch.line(to: NSPoint(x: 272, y: 824))
    notch.close()
    NSColor(calibratedRed: 0.078, green: 0.100, blue: 0.155, alpha: 1).setFill()
    notch.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // 白色卷标只保留产品识别文字 A247。
    let labelRect = NSRect(x: 330, y: 438, width: 364, height: 248)
    let label = roundedRect(labelRect, radius: 28)
    let labelGradient = NSGradient(colors: [
        NSColor(calibratedWhite: 1.0, alpha: 1),
        NSColor(calibratedWhite: 0.90, alpha: 1)
    ])!
    labelGradient.draw(in: label, angle: -90)

    drawCentered(
        "A247",
        in: labelRect.offsetBy(dx: 0, dy: 5),
        attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 108, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.02, green: 0.49, blue: 1.0, alpha: 1),
            .kern: -7
        ]
    )

    // 少量、加粗的金色触点，在 16–32 px 下仍能辨认出存储卡。
    NSGraphicsContext.current?.saveGraphicsState()
    NSShadow().set()
    for index in 0..<6 {
        let contactRect = NSRect(x: 344 + CGFloat(index) * 61, y: 236, width: 38, height: 118)
        let contact = roundedRect(contactRect, radius: 11)
        let contactGradient = NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.28, alpha: 1),
            NSColor(calibratedRed: 0.82, green: 0.56, blue: 0.10, alpha: 1)
        ])!
        contactGradient.draw(in: contact, angle: -90)
    }
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

let outputURL: URL
if let outputPath = CommandLine.arguments.dropFirst().first {
    outputURL = URL(fileURLWithPath: outputPath)
} else {
    outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("AppIconMaster.png")
}

let bitmap = renderIcon()
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fputs("无法编码 PNG 图标。\n", stderr)
    exit(1)
}

do {
    try data.write(to: outputURL, options: .atomic)
    print("已生成图标母版：\(outputURL.path)")
} catch {
    fputs("无法写入图标：\(error.localizedDescription)\n", stderr)
    exit(1)
}

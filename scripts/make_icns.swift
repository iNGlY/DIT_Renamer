import AppKit

guard CommandLine.arguments.count >= 2 else {
    fputs("用法：swift scripts/make_icns.swift <母版.png> [输出.iconset]\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetURL = CommandLine.arguments.count >= 3
    ? URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    : URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        .appendingPathComponent("AppIcon.iconset", isDirectory: true)

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fputs("无法读取图标母版：\(sourceURL.path)\n", stderr)
    exit(1)
}

let fileManager = FileManager.default
do {
    if fileManager.fileExists(atPath: iconsetURL.path) {
        try fileManager.removeItem(at: iconsetURL)
    }
    try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
} catch {
    fputs("无法准备 iconset：\(error.localizedDescription)\n", stderr)
    exit(1)
}

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for item in sizes {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: item.pixels,
        pixelsHigh: item.pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fputs("无法创建 \(item.pixels) px 图标。\n", stderr)
        exit(1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    sourceImage.draw(
        in: NSRect(x: 0, y: 0, width: item.pixels, height: item.pixels),
        from: NSRect(origin: .zero, size: sourceImage.size),
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fputs("无法编码 \(item.name)。\n", stderr)
        exit(1)
    }

    do {
        try data.write(to: iconsetURL.appendingPathComponent(item.name), options: .atomic)
    } catch {
        fputs("无法写入 \(item.name)：\(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

print("已生成 iconset：\(iconsetURL.path)")

import AppKit

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: swift scripts/make_icns.swift <source.png> [output.iconset]\n", stderr)
    exit(2)
}

let iconURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetURL = CommandLine.arguments.count >= 3
    ? URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    : URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        .appendingPathComponent("AppIcon.iconset", isDirectory: true)

guard let baseImage = NSImage(contentsOf: iconURL) else {
    fputs("Could not load source PNG at \(iconURL.path)\n", stderr)
    exit(1)
}

let fm = FileManager.default
do {
    if fm.fileExists(atPath: iconsetURL.path) {
        try fm.removeItem(at: iconsetURL)
    }
    try fm.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
} catch {
    fputs("Could not prepare \(iconsetURL.path): \(error)\n", stderr)
    exit(1)
}

let sizes: [(String, Int)] = [
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

for (filename, px) in sizes {
    let destSize = NSSize(width: px, height: px)
    let resized = NSImage(size: destSize)
    resized.lockFocus()
    baseImage.draw(in: NSRect(origin: .zero, size: destSize), from: NSRect(origin: .zero, size: baseImage.size), operation: .copy, fraction: 1.0)
    resized.unlockFocus()
    
    if let tiffData = resized.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        let destURL = iconsetURL.appendingPathComponent(filename)
        do {
            try pngData.write(to: destURL)
        } catch {
            fputs("Could not write \(destURL.path): \(error)\n", stderr)
            exit(1)
        }
    }
}

print("Created iconset at \(iconsetURL.path)")

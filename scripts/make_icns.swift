import AppKit

let iconPath = "/Users/Do2n4c7rY/.gemini/antigravity-ide/brain/b38a126b-6315-4eb3-bb93-8d4856376c5c/apple_icon_dark_grid.png"
guard let baseImage = NSImage(contentsOfFile: iconPath) else {
    print("Failed to load base PNG")
    exit(1)
}

let fm = FileManager.default
let iconsetDir = "/Users/Do2n4c7rY/Downloads/DIT_Renamer/AppIcon.iconset"
try? fm.removeItem(atPath: iconsetDir)
try? fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true, attributes: nil)

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
        let destURL = URL(fileURLWithPath: "\(iconsetDir)/\(filename)")
        try? pngData.write(to: destURL)
    }
}

print("ICONSET CREATED SUCCESSFULLY!")

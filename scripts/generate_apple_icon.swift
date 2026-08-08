import AppKit

func renderIcon(isDark: Bool) -> NSImage {
    let size = NSSize(width: 512, height: 512)
    let image = NSImage(size: size)
    
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return image }
    
    // 1. Background Squircle
    let squirclePath = NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 448, height: 448), xRadius: 100, yRadius: 100)
    
    if isDark {
        let bgGradient = NSGradient(starting: NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.16, alpha: 1.0),
                                    ending: NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.08, alpha: 1.0))
        bgGradient?.draw(in: squirclePath, angle: -45)
        NSColor(white: 1.0, alpha: 0.15).setStroke()
    } else {
        let bgGradient = NSGradient(starting: NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1.0),
                                    ending: NSColor(calibratedRed: 0.86, green: 0.89, blue: 0.94, alpha: 1.0))
        bgGradient?.draw(in: squirclePath, angle: -45)
        NSColor(white: 1.0, alpha: 0.8).setStroke()
    }
    squirclePath.lineWidth = 3
    squirclePath.stroke()
    
    // 2. Draw Precision Background Grid (在背后加入网格)
    ctx.saveGState()
    squirclePath.addClip()
    
    let gridColor = isDark ? NSColor(calibratedRed: 0.04, green: 0.52, blue: 1.0, alpha: 0.18) : NSColor(calibratedRed: 0.0, green: 0.4, blue: 0.8, alpha: 0.08)
    gridColor.setStroke()
    
    let gridPath = NSBezierPath()
    gridPath.lineWidth = 1.0
    let step: CGFloat = 28
    
    for x in stride(from: 32, to: 480, by: step) {
        gridPath.move(to: NSPoint(x: x, y: 32))
        gridPath.line(to: NSPoint(x: x, y: 480))
    }
    for y in stride(from: 32, to: 480, by: step) {
        gridPath.move(to: NSPoint(x: 32, y: y))
        gridPath.line(to: NSPoint(x: 480, y: y))
    }
    gridPath.stroke()
    ctx.restoreGState()
    
    // 3. Draw Straight Upright Memory Card (把卡放正)
    ctx.saveGState()
    ctx.translateBy(x: 256, y: 235)
    
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(isDark ? 0.5 : 0.25)
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.shadowBlurRadius = 18
    shadow.set()
    
    // Card Body (Straight)
    let cardRect = NSRect(x: -105, y: -135, width: 210, height: 270)
    let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 16, yRadius: 16)
    
    if isDark {
        NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.22, alpha: 1.0).setFill()
    } else {
        NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.26, alpha: 1.0).setFill()
    }
    cardPath.fill()
    
    // Top Notch
    let notchPath = NSBezierPath()
    notchPath.move(to: NSPoint(x: -105, y: 105))
    notchPath.line(to: NSPoint(x: -75, y: 135))
    notchPath.line(to: NSPoint(x: -105, y: 135))
    notchPath.close()
    (isDark ? NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.16, alpha: 1.0) : NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)).setFill()
    notchPath.fill()
    
    // Label Box
    let labelRect = NSRect(x: -80, y: -35, width: 160, height: 125)
    let labelPath = NSBezierPath(roundedRect: labelRect, xRadius: 10, yRadius: 10)
    NSColor.white.setFill()
    labelPath.fill()
    
    // Label Text "A001"
    let textStr = "A001"
    let font = NSFont.monospacedSystemFont(ofSize: 40, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(calibratedRed: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)
    ]
    let attrStr = NSAttributedString(string: textStr, attributes: attrs)
    let textSize = attrStr.size()
    attrStr.draw(at: NSPoint(x: -textSize.width / 2, y: 25))
    
    // Subtext "DJI 4D · ROLL"
    let subStr = "DJI 4D · ROLL"
    let subFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor.secondaryLabelColor
    ]
    let subAttrStr = NSAttributedString(string: subStr, attributes: subAttrs)
    let subTextSize = subAttrStr.size()
    subAttrStr.draw(at: NSPoint(x: -subTextSize.width / 2, y: -8))
    
    // Gold Pins
    for i in 0..<7 {
        let pinX = -70 + CGFloat(i) * 21
        let pinRect = NSRect(x: pinX, y: -120, width: 13, height: 42)
        let pinPath = NSBezierPath(roundedRect: pinRect, xRadius: 3, yRadius: 3)
        NSColor(calibratedRed: 0.92, green: 0.72, blue: 0.22, alpha: 1.0).setFill()
        pinPath.fill()
    }
    
    ctx.restoreGState()
    
    // 4. Apple Pencil (Angle Pointing to Label)
    ctx.saveGState()
    ctx.translateBy(x: 350, y: 330)
    ctx.rotate(by: -0.55)
    
    let pencilShadow = NSShadow()
    pencilShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    pencilShadow.shadowOffset = NSSize(width: 8, height: -12)
    pencilShadow.shadowBlurRadius = 12
    pencilShadow.set()
    
    let pencilRect = NSRect(x: -11, y: -150, width: 22, height: 250)
    let pencilPath = NSBezierPath(roundedRect: pencilRect, xRadius: 11, yRadius: 11)
    NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.99, alpha: 1.0).setFill()
    pencilPath.fill()
    
    let tipPath = NSBezierPath()
    tipPath.move(to: NSPoint(x: -11, y: -150))
    tipPath.line(to: NSPoint(x: 11, y: -150))
    tipPath.line(to: NSPoint(x: 0, y: -200))
    tipPath.close()
    NSColor(calibratedRed: 0.88, green: 0.88, blue: 0.90, alpha: 1.0).setFill()
    tipPath.fill()
    
    let nibPath = NSBezierPath()
    nibPath.move(to: NSPoint(x: -4, y: -183))
    nibPath.line(to: NSPoint(x: 4, y: -183))
    nibPath.line(to: NSPoint(x: 0, y: -200))
    nibPath.close()
    NSColor(calibratedRed: 0.20, green: 0.20, blue: 0.22, alpha: 1.0).setFill()
    nibPath.fill()
    
    ctx.restoreGState()
    
    image.unlockFocus()
    return image
}

// Render Light and Dark Mode Icons
let lightIcon = renderIcon(isDark: false)
let darkIcon = renderIcon(isDark: true)

func savePNG(_ image: NSImage, filename: String) {
    if let tiffData = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: "/Users/Do2n4c7rY/.gemini/antigravity-ide/brain/b38a126b-6315-4eb3-bb93-8d4856376c5c/\(filename)")
        try? pngData.write(to: url)
    }
}

savePNG(lightIcon, filename: "apple_icon_light_grid.png")
savePNG(darkIcon, filename: "apple_icon_dark_grid.png")
print("BOTH LIGHT AND DARK GRID ICONS RENDERED SUCCESSFULLY!")

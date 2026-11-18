// Draws the Vaelos Silicon logo: a glowing "V" etched into a silicon die, on a macOS-style squircle.
// Usage: swift packaging/make-icon.swift <out.png>      (1024x1024; build-app.sh turns it into AppIcon.icns)
// The same geometry is in site/logo.svg (SVG's y axis points down: y_svg = 1024 - y).
import AppKit

let size = 1024.0
let center = size / 2

func color(_ hex: UInt32, _ alpha: Double = 1) -> NSColor {
    NSColor(srgbRed: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha)
}

let cyan = color(0x22D3EE)
let violet = color(0x8B5CF6)
let magenta = color(0xEC4899)

// MARK: Pieces

/// The macOS icon shape: 824 px rounded square with 100 px margins.
func drawBackground() -> NSBezierPath {
    let squircle = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 186, yRadius: 186)
    NSGradient(starting: color(0x1B2140), ending: color(0x05070D))!.draw(in: squircle, angle: -60)
    // Violet glow behind the chip.
    NSGradient(colors: [violet.withAlphaComponent(0.35), violet.withAlphaComponent(0)])!
        .draw(in: squircle, relativeCenterPosition: NSPoint(x: 0, y: -0.05))
    return squircle
}

/// Faint wafer grid, clipped to the squircle.
func drawGrid(inside squircle: NSBezierPath) {
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    color(0xFFFFFF, 0.04).setStroke()
    let spacing = 824.0 / 20
    for line in 0...20 {
        let offset = 100 + Double(line) * spacing
        let vertical = NSBezierPath()
        vertical.move(to: NSPoint(x: offset, y: 100))
        vertical.line(to: NSPoint(x: offset, y: 924))
        vertical.lineWidth = 2
        vertical.stroke()
        let horizontal = NSBezierPath()
        horizontal.move(to: NSPoint(x: 100, y: offset))
        horizontal.line(to: NSPoint(x: 924, y: offset))
        horizontal.lineWidth = 2
        horizontal.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
}

/// The die: a dark rounded square with 7 pins on each side.
func drawChip() {
    let half = 235.0
    let pinLength = 46.0
    let pinWidth = 18.0
    color(0x8EA2FF, 0.55).setFill()
    for pin in 0..<7 {
        let along = center - 180 + Double(pin) * 60        // pin centres along each edge
        NSBezierPath(roundedRect: NSRect(x: along - pinWidth / 2, y: center + half - 6, width: pinWidth, height: pinLength), xRadius: 5, yRadius: 5).fill()
        NSBezierPath(roundedRect: NSRect(x: along - pinWidth / 2, y: center - half - pinLength + 6, width: pinWidth, height: pinLength), xRadius: 5, yRadius: 5).fill()
        NSBezierPath(roundedRect: NSRect(x: center - half - pinLength + 6, y: along - pinWidth / 2, width: pinLength, height: pinWidth), xRadius: 5, yRadius: 5).fill()
        NSBezierPath(roundedRect: NSRect(x: center + half - 6, y: along - pinWidth / 2, width: pinLength, height: pinWidth), xRadius: 5, yRadius: 5).fill()
    }

    let die = NSBezierPath(roundedRect: NSRect(x: center - half, y: center - half, width: 2 * half, height: 2 * half), xRadius: 64, yRadius: 64)
    NSGradient(starting: color(0x161C33), ending: color(0x0A0D19))!.draw(in: die, angle: -90)
    die.lineWidth = 5
    cyan.withAlphaComponent(0.45).setStroke()
    die.stroke()
}

/// The "V": one thick chevron with a neon gradient and glow, plus a circuit trace from its tip.
func drawMonogram() {
    let v = NSBezierPath()
    v.move(to: NSPoint(x: 330, y: 680))
    v.line(to: NSPoint(x: 412, y: 680))
    v.line(to: NSPoint(x: 512, y: 448))
    v.line(to: NSPoint(x: 612, y: 680))
    v.line(to: NSPoint(x: 694, y: 680))
    v.line(to: NSPoint(x: 548, y: 352))
    v.line(to: NSPoint(x: 476, y: 352))
    v.close()

    // Glow first, then the crisp gradient fill on top.
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = violet.withAlphaComponent(0.9)
    glow.shadowBlurRadius = 48
    glow.set()
    violet.setFill()
    v.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [cyan, violet, magenta])!.draw(in: v, angle: -70)

    // Etched facet across the left arm.
    let facet = NSBezierPath()
    facet.move(to: NSPoint(x: 362, y: 610))
    facet.line(to: NSPoint(x: 440, y: 610))
    facet.lineWidth = 6
    color(0x0A0D19, 0.85).setStroke()
    facet.stroke()

    // Circuit trace down from the tip, ending in a node.
    let trace = NSBezierPath()
    trace.move(to: NSPoint(x: 512, y: 352))
    trace.line(to: NSPoint(x: 512, y: 300))
    trace.lineWidth = 8
    cyan.setStroke()
    trace.stroke()
    cyan.setFill()
    NSBezierPath(ovalIn: NSRect(x: 498, y: 282, width: 28, height: 28)).fill()
}

// MARK: Render

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let squircle = drawBackground()
drawGrid(inside: squircle)
drawChip()
drawMonogram()
squircle.lineWidth = 3
color(0xFFFFFF, 0.08).setStroke()
squircle.stroke()
image.unlockFocus()

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png")
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! bitmap.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)")

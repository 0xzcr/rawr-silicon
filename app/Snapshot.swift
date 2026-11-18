// Draws the window to a PNG without showing it (checking the layout needs no screen-recording permission).
import AppKit
import SwiftUI

func writeSnapshot(to path: String, dark: Bool, preset: Preset, setup: SetupState) {
    let view = ContentView(model: Model(preset: preset, setup: setup))
        .background(Color(nsColor: .windowBackgroundColor))   // a real window paints this itself
    let hosting = NSHostingView(rootView: view)
    hosting.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)

    let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = hosting
    hosting.layoutSubtreeIfNeeded()

    guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
}

// The two graphics presets, and the display the game opens on.
import AppKit

/// The display the game opens on. Wine puts fullscreen games on macOS's primary display (the one with the
/// menu bar), not on whichever screen our window happens to be on.
func gameScreen() -> NSScreen? {
    NSScreen.screens.first
}

/// Measured on an M2 Max, Dust2 with 10 bots: Smooth ~130 fps, Sharp ~90 fps (see docs/RESULTS.md).
enum Preset: String, CaseIterable, Identifiable {
    case smooth = "Smooth"
    case sharp = "Sharp"

    var id: String { rawValue }

    var caption: String {
        switch self {
        case .smooth: return "Half resolution, highest fps. Best for competitive play."
        case .sharp: return "Full Retina resolution, lower fps."
        }
    }

    /// Fullscreen size on `screen`: real pixels for Sharp (needs Wine's Retina mode), macOS's scaled size for Smooth.
    /// Both are the display's current mode, so the screen never switches modes.
    func resolution(on screen: NSScreen) -> (width: Int, height: Int) {
        let scale = self == .sharp ? screen.backingScaleFactor : 1
        let width = Int(screen.frame.width * scale)
        let height = Int(screen.frame.height * scale)
        return (width, height)
    }
}

import SwiftUI

public extension Color {
    /// The default gauge / ring / progress-bar tint of a complication that has no color of its own —
    /// the Home Assistant primary brand color (`#009AC7`), which is also what the builder's color
    /// picker shows as its starting value.
    ///
    /// Spelled out rather than `.accentColor` on purpose: the accent color resolves per *target*, so
    /// the very same complication drew brand blue in the iPhone builder preview (the app's accent
    /// asset) and the system default on the watch face (the WatchWidgets extension declares no accent
    /// color) — the two only agreed once the user picked a color by hand. Every surface that renders a
    /// complication resolves its missing tint through this one constant instead.
    ///
    /// A literal, not the shared `haPrimary` asset: this package is deliberately dependency-free so a
    /// watch widget extension can link it on its own (see `WatchWidgets`' own mirrored copy).
    static let complicationDefaultTint = Color(red: 0, green: 154 / 255, blue: 199 / 255)
}

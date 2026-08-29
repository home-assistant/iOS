@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

struct AssistVoiceOrbViewSnapshotTests {
    /// Any point of the animation timeline does, as long as it is the same one on every run: the blobs
    /// are placed from the time they are handed, so a live timeline would move them together between
    /// recordings.
    private static let fixedTime: TimeInterval = 100
    private static let size: CGFloat = 160

    /// Dark mode only, and in the legacy appearance, because this close-up is the one place the orb
    /// fills the frame and so cannot absorb any difference in how the OS draws it:
    ///
    /// - Liquid Glass and the light appearance's system colours (`.cyan`, `.teal`) over white both
    ///   shift between OS versions by more than the comparison tolerance allows, so a reference
    ///   recorded on one runtime fails on another.
    /// - The dark appearance is spelled out in fixed palette values on a near-black background, which
    ///   renders identically across runtimes.
    ///
    /// The light appearance and the glass orb are covered by `AssistViewSnapshotTests`, where the orb
    /// is a small part of the screen. What this test pins is the dark palette the orb picks.
    @available(iOS 18, *)
    @MainActor @Test(arguments: [0.0, 0.5, 1.0]) func snapshots(level: Double) {
        let view = AssistVoiceOrbView(level: level, accessibilityLabel: "Listening", forcesLegacyAppearance: true)
            .frame(width: Self.size, height: Self.size)
            .background(Color(uiColor: .systemBackground))
            .environment(\.assistOrbFixedTime, Self.fixedTime)

        assertSnapshot(
            of: view,
            // The orb is drawn from blurs, which the render server composites: a layer-based capture
            // comes back with only the microphone glyph on a transparent background.
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: Self.size, height: Self.size),
            traits: .init(userInterfaceStyle: .dark),
            named: "level-\(Int(level * 100))-dark"
        )
    }
}

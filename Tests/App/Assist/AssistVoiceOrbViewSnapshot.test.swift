@testable import HomeAssistant
import SharedTesting
import SwiftUI
import Testing

struct AssistVoiceOrbViewSnapshotTests {
    /// Any point of the animation timeline does, as long as it is the same one on every run: the blobs
    /// are placed from the time they are handed, so a live timeline would move them between recordings.
    private static let fixedTime: TimeInterval = 100
    private static let size: CGFloat = 160

    @available(iOS 18, *)
    @MainActor @Test(arguments: [0.0, 0.5, 1.0]) func snapshots(level: Double) {
        let view = AssistVoiceOrbView(level: level)
            .frame(width: Self.size, height: Self.size)
            .background(Color(uiColor: .systemBackground))
            .environment(\.assistOrbFixedTime, Self.fixedTime)

        assertLightDarkSnapshots(
            of: view,
            // The orb is blurs and Liquid Glass, which the render server draws: a layer-based capture
            // comes back with only the microphone glyph on a transparent background.
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: Self.size, height: Self.size),
            named: "level-\(Int(level * 100))"
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func legacySnapshots() {
        let view = AssistVoiceOrbView(level: 0.5, forcesLegacyAppearance: true)
            .frame(width: Self.size, height: Self.size)
            .background(Color(uiColor: .systemBackground))
            .environment(\.assistOrbFixedTime, Self.fixedTime)

        assertLightDarkSnapshots(
            of: view,
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: Self.size, height: Self.size),
            named: "legacy-level-50"
        )
    }
}

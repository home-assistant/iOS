@testable import HomeAssistant
import SharedTesting
import SwiftUI
import Testing

struct AssistVoiceOrbViewSnapshotTests {
    /// Any point of the animation timeline does, as long as it is the same one on every run: the blobs
    /// are placed from the time they are handed, so a live timeline would move them between recordings.
    private static let fixedTime: TimeInterval = 100
    private static let size: CGFloat = 160

    /// Rendered in the legacy appearance on purpose. Liquid Glass is drawn by the system and comes out
    /// differently from one OS version to the next, so at this size — where the orb is most of the
    /// frame — a reference recorded on one runtime cannot match another within the comparison's
    /// tolerance. The glass orb is covered by `AssistViewSnapshotTests.listening()`, where it is small
    /// enough for the tolerance to hold. What this test pins is the orb's own colours, which the two
    /// appearances share.
    @available(iOS 18, *)
    @MainActor @Test(arguments: [0.0, 0.5, 1.0]) func snapshots(level: Double) {
        let view = AssistVoiceOrbView(level: level, forcesLegacyAppearance: true)
            .frame(width: Self.size, height: Self.size)
            .background(Color(uiColor: .systemBackground))
            .environment(\.assistOrbFixedTime, Self.fixedTime)

        assertLightDarkSnapshots(
            of: view,
            // The orb is drawn from blurs, which the render server composites: a layer-based capture
            // comes back with only the microphone glyph on a transparent background.
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: Self.size, height: Self.size),
            named: "level-\(Int(level * 100))"
        )
    }
}

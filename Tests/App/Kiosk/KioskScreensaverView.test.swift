import HAModels
@testable import HomeAssistant
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

struct KioskScreensaverViewTests {
    /// Dim mode is a translucent black cover over the whole display, edge to edge. The clock mode
    /// shows the live time, so it is the dim mode that can be pinned to an image.
    @MainActor @Test func dimModeCoversTheDisplay() async throws {
        guard #available(iOS 18.0, *) else { return }

        var settings = KioskScreensaverSettings()
        settings.mode = .dim
        settings.dimLevel = 0.5

        assertLightDarkSnapshots(
            of: AnyView(
                ZStack {
                    Color.white
                    KioskScreensaverView(settings: settings, onWake: {})
                }
            ),
            layout: .fixed(width: 200, height: 120),
            named: "screensaver-dim"
        )
    }
}

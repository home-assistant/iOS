@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

struct ViewScreenCaptureProtectionTests {
    /// Nothing is being captured while the tests run, so the protected content renders unblurred.
    @MainActor @Test func uncapturedContentRendersUnblurred() async throws {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: AnyView(
                Text("http://homeassistant.local:8123")
                    .screenCaptureProtected()
                    .padding()
            ),
            layout: .fixed(width: 320, height: 80),
            named: "screen-capture-protected"
        )
    }

    /// The iOS 16 fallback reads the main screen instead of the scene; it renders the same way when
    /// nothing is captured.
    @MainActor @Test func legacyFallbackRendersUnblurred() async throws {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: AnyView(
                Text("http://homeassistant.local:8123")
                    .modifier(ScreenCaptureProtectionModifier.LegacyScreenCaptureBlur(blurRadius: 16))
                    .padding()
            ),
            layout: .fixed(width: 320, height: 80),
            named: "screen-capture-protected-legacy"
        )
    }
}

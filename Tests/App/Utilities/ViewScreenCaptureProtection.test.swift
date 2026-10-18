@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

struct ViewScreenCaptureProtectionTests {
    private static let layout = SwiftUISnapshotLayout.fixed(width: 320, height: 80)

    /// Nothing is being captured while the tests run, so the protected content renders unblurred.
    @MainActor @Test func uncapturedContentRendersUnblurred() async throws {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: AnyView(protectedText.screenCaptureProtected()),
            layout: Self.layout,
            named: "screen-capture-protected"
        )
    }

    /// Both capture sources feed the same blur. The snapshot renderer draws no blur off screen, so
    /// the captured look is checked by rendering in process and comparing against the uncaptured one.
    @MainActor @Test func capturedContentRendersBlurred() async throws {
        guard #available(iOS 18.0, *) else { return }

        let captured = try #require(render(isCaptured: true))
        let uncaptured = try #require(render(isCaptured: false))

        #expect(captured != uncaptured)
    }

    @MainActor
    private func render(isCaptured: Bool) -> Data? {
        let renderer = ImageRenderer(
            content: protectedText
                .modifier(ScreenCaptureProtectionModifier.CaptureBlur(isCaptured: isCaptured, blurRadius: 16))
                .frame(width: 320, height: 80)
        )
        renderer.scale = 2
        return renderer.uiImage?.pngData()
    }

    /// The iOS 16 fallback reads the main screen instead of the scene; it renders the same way when
    /// nothing is captured.
    @MainActor @Test func legacyFallbackRendersUnblurred() async throws {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: AnyView(protectedText.modifier(
                ScreenCaptureProtectionModifier.LegacyScreenCaptureBlur(blurRadius: 16)
            )),
            layout: Self.layout,
            named: "screen-capture-protected-legacy"
        )
    }

    private var protectedText: some View {
        Text("http://homeassistant.local:8123")
            .padding()
    }
}

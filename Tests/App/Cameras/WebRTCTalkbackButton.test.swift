@testable import HomeAssistant
@testable import Shared
import SnapshotTesting
import SwiftUI
import Testing

struct WebRTCTalkbackButtonTests {
    @MainActor
    @Test func idle() {
        assert(.init(state: .idle, action: {}))
    }

    @MainActor
    @Test func connecting() {
        assert(.init(state: .connecting, action: {}))
    }

    @MainActor
    @Test func talking() {
        assert(.init(state: .talking, action: {}))
    }

    @MainActor
    @Test func microphoneDenied() {
        let button = WebRTCTalkbackButton(
            state: .idle,
            errorMessage: L10n.CameraMicrophone.Errors.microphoneDenied,
            action: {}
        )
        assert(button)
    }

    /// The button is drawn on Liquid Glass, which only the render server draws, so the snapshot is
    /// taken from the key window.
    private func assert(
        _ button: WebRTCTalkbackButton,
        testName: String = #function
    ) {
        assertLightDarkSnapshots(
            of: streamFrame(button),
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 260),
            testName: testName
        )
    }

    private func streamFrame(_ button: WebRTCTalkbackButton) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)
            button
                .padding(DesignSystem.Spaces.three)
        }
        .frame(width: 390, height: 260)
    }
}

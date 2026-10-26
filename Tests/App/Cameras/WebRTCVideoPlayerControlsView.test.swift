@testable import HomeAssistant
@testable import Shared
import SnapshotTesting
import SwiftUI
import Testing

struct WebRTCVideoPlayerControlsViewTests {
    @MainActor
    @Test func microphoneIdle() {
        assertLightDarkSnapshots(
            of: controls(isTalkbackSupported: true, talkbackState: .idle),
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor
    @Test func microphoneLive() {
        assertLightDarkSnapshots(
            of: controls(isTalkbackSupported: true, talkbackState: .talking),
            drawHierarchyInKeyWindow: true
        )
    }

    /// Kiosks are mostly iPads in landscape, the layout the overlay is designed around.
    @MainActor
    @Test func microphoneIdleOnIPad() {
        assertLightDarkSnapshots(
            of: controls(isTalkbackSupported: true, talkbackState: .idle),
            drawHierarchyInKeyWindow: true,
            layout: .device(config: .iPadPro12_9(.landscape))
        )
    }

    /// The rest of the controls are tapped away, but a live microphone stays so it can be hung up.
    @MainActor
    @Test func talkingWithControlsHidden() {
        assertLightDarkSnapshots(
            of: controls(isTalkbackSupported: true, talkbackState: .talking, controlsVisible: false),
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor
    @Test func withoutTwoWayAudio() {
        assertLightDarkSnapshots(
            of: controls(isTalkbackSupported: false, talkbackState: .idle),
            drawHierarchyInKeyWindow: true
        )
    }

    private func controls(
        isTalkbackSupported: Bool,
        talkbackState: WebRTCTalkbackState,
        controlsVisible: Bool = true
    ) -> some View {
        WebRTCVideoPlayerControlsView(
            controlsVisible: .constant(controlsVisible),
            isTalkbackSupported: isTalkbackSupported,
            talkbackState: talkbackState,
            talkbackError: nil,
            isMuted: false,
            onToggleTalkback: {},
            onToggleMute: {}
        ) {
            LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)
        }
    }
}

@testable import HomeAssistant
import SharedTesting
import SwiftUI
import Testing

/// Lays out the controls over a stand-in player so the talkback and mute buttons are built.
@MainActor
struct WebRTCVideoPlayerControlsViewRenderTests {
    @Test func rendersWithAndWithoutTalkback() {
        for supportsTalkback in [true, false] {
            renderInWindow(WebRTCVideoPlayerControlsView(
                controlsVisible: .constant(true),
                isTalkbackSupported: supportsTalkback,
                isTalking: false,
                isMuted: true,
                onToggleTalkback: {},
                onToggleMute: {}
            ) {
                Color.black
            })
        }
    }
}

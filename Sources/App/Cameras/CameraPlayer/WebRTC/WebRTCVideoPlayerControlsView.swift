import HADesignSystem
import SFSafeSymbols
import Shared
import SwiftUI

/// Floats the WebRTC player's own controls over the stream: mute in the top trailing corner, lined
/// up with the close button and camera name `CameraPlayerView` draws in the leading one, and the
/// microphone at the bottom center when the camera supports two-way audio.
struct WebRTCVideoPlayerControlsView<Content: View>: View {
    @Binding private var controlsVisible: Bool

    private let isTalkbackSupported: Bool
    private let talkbackState: WebRTCTalkbackState
    private let talkbackError: String?
    private let isMuted: Bool
    private let onToggleTalkback: () -> Void
    private let onToggleMute: () -> Void
    private let content: Content

    private let controlSize: CGFloat = 44

    init(
        controlsVisible: Binding<Bool>,
        isTalkbackSupported: Bool,
        talkbackState: WebRTCTalkbackState,
        talkbackError: String?,
        isMuted: Bool,
        onToggleTalkback: @escaping () -> Void,
        onToggleMute: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self._controlsVisible = controlsVisible
        self.isTalkbackSupported = isTalkbackSupported
        self.talkbackState = talkbackState
        self.talkbackError = talkbackError
        self.isMuted = isMuted
        self.onToggleTalkback = onToggleTalkback
        self.onToggleMute = onToggleMute
        self.content = content()
    }

    var body: some View {
        content
            .overlay(alignment: .topTrailing) {
                if controlsVisible {
                    Button(action: onToggleMute) {
                        Image(systemSymbol: isMuted ? .speakerSlashFill : .speakerWave2Fill)
                            .font(DesignSystem.Font.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: controlSize, height: controlSize)
                            .haGlassBackground(in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isMuted ? L10n.Component.MediaControl.unmute : L10n.Component.MediaControl.mute)
                    .padding(DesignSystem.Spaces.two)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                // A live microphone stays reachable when the rest of the controls are tapped away, so
                // it can always be hung up, and so does the reason it stopped when it fails.
                if isTalkbackSupported, controlsVisible || talkbackState != .idle || talkbackError != nil {
                    WebRTCTalkbackButton(state: talkbackState, errorMessage: talkbackError, action: onToggleTalkback)
                        .padding(.horizontal, DesignSystem.Spaces.two)
                        .padding(.bottom, DesignSystem.Spaces.three)
                        // Centered on the screen rather than between the safe areas: a device whose
                        // side insets differ, such as iPhone Duo around its camera, would otherwise
                        // push it off center. The top row keeps its insets to stay clear of that camera.
                        .frame(maxWidth: .infinity)
                        .ignoresSafeArea(.container, edges: .horizontal)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: controlsVisible)
    }
}

#if DEBUG
#Preview("Mic idle") {
    WebRTCVideoPlayerControlsView(
        controlsVisible: .constant(true),
        isTalkbackSupported: true,
        talkbackState: .idle,
        talkbackError: nil,
        isMuted: false,
        onToggleTalkback: {},
        onToggleMute: {}
    ) {
        LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
    .preferredColorScheme(.dark)
}

#Preview("Mic on") {
    WebRTCVideoPlayerControlsView(
        controlsVisible: .constant(true),
        isTalkbackSupported: true,
        talkbackState: .talking,
        talkbackError: nil,
        isMuted: true,
        onToggleTalkback: {},
        onToggleMute: {}
    ) {
        LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
    .preferredColorScheme(.dark)
}

#Preview("No two-way audio") {
    WebRTCVideoPlayerControlsView(
        controlsVisible: .constant(true),
        isTalkbackSupported: false,
        talkbackState: .idle,
        talkbackError: nil,
        isMuted: true,
        onToggleTalkback: {},
        onToggleMute: {}
    ) {
        LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
    .preferredColorScheme(.dark)
}
#endif

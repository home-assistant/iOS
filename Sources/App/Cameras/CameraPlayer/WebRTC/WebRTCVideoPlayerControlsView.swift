import HADesignSystem
import SFSafeSymbols
import Shared
import SwiftUI

struct WebRTCVideoPlayerControlsView<Content: View>: View {
    @Binding private var controlsVisible: Bool

    private let isTalkbackSupported: Bool
    private let isTalking: Bool
    private let isMuted: Bool
    private let onToggleTalkback: () -> Void
    private let onToggleMute: () -> Void
    private let content: Content

    init(
        controlsVisible: Binding<Bool>,
        isTalkbackSupported: Bool,
        isTalking: Bool,
        isMuted: Bool,
        onToggleTalkback: @escaping () -> Void,
        onToggleMute: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self._controlsVisible = controlsVisible
        self.isTalkbackSupported = isTalkbackSupported
        self.isTalking = isTalking
        self.isMuted = isMuted
        self.onToggleTalkback = onToggleTalkback
        self.onToggleMute = onToggleMute
        self.content = content()
    }

    var body: some View {
        content
            .overlay {
                if controlsVisible, isTalkbackSupported {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 180)
                    }
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            .toolbar {
                talkbackToolbarItem
                muteToolbarItem
            }
    }

    @ToolbarContentBuilder
    private var talkbackToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            if controlsVisible, isTalkbackSupported {
                Button(action: onToggleTalkback) {
                    HStack {
                        if isTalking {
                            Text(L10n.CameraPlayer.Talkback.stop)
                                .font(.headline)
                                .padding(.trailing, DesignSystem.Spaces.one)
                        }
                        Image(systemSymbol: isTalking ? .micSlash : .micFill)
                            .font(DesignSystem.Font.title3)
                    }
                    .padding(.vertical, DesignSystem.Spaces.four)
                    .padding(.horizontal, isTalking ? DesignSystem.Spaces.one : DesignSystem.Spaces.four)
                    .transition(.move(edge: .trailing).combined(with: .scale))
                }
                .modify({ view in
                    if #available(iOS 26.0, *) {
                        view
                            .buttonStyle(.glassProminent)
                    } else {
                        view
                    }
                })
                .tint(isTalking ? Color.orange : Color.haPrimary)
                .contentShape(.capsule)
                .accessibilityLabel(
                    isTalking ? L10n.CameraPlayer.Talkback.stop : L10n.CameraPlayer.Talkback.start
                )
            }
        }
    }

    @ToolbarContentBuilder
    private var muteToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if controlsVisible {
                Button(action: onToggleMute) {
                    Image(systemSymbol: isMuted ? .speakerSlashFill : .speakerWave3)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Mic standby") {
    NavigationStack {
        WebRTCVideoPlayerControlsView(
            controlsVisible: .constant(true),
            isTalkbackSupported: true,
            isTalking: false,
            isMuted: false,
            onToggleTalkback: {},
            onToggleMute: {}
        ) {
            Rectangle()
                .fill(.black)
                .overlay {
                    Text("Camera preview")
                        .foregroundStyle(.white)
                }
                .ignoresSafeArea()
        }
    }
}

#Preview("Mic on") {
    NavigationStack {
        WebRTCVideoPlayerControlsView(
            controlsVisible: .constant(true),
            isTalkbackSupported: true,
            isTalking: true,
            isMuted: false,
            onToggleTalkback: {},
            onToggleMute: {}
        ) {
            Rectangle()
                .fill(.black)
                .overlay {
                    Text("Camera preview")
                        .foregroundStyle(.white)
                }
                .ignoresSafeArea()
        }
    }
}
#endif

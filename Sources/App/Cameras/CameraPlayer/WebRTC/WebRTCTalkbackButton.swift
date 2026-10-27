import SFSafeSymbols
import Shared
import SwiftUI

/// The microphone toggle at the bottom of the camera player: a glass circle while idle or
/// connecting, growing into an orange "Stop talking" capsule while the microphone is live.
struct WebRTCTalkbackButton: View {
    private let state: WebRTCTalkbackState
    private let errorMessage: String?
    private let action: () -> Void

    private let buttonSize: CGFloat = DesignSystem.Spaces.nine

    /// Glass softens its tint, but before iOS 26 the tint is a solid fill, where white text on plain
    /// orange falls short of a readable contrast. That fill is a darker orange instead, so the label
    /// stays white like every other control over the stream.
    private var talkingTint: Color {
        if #available(iOS 26.0, *) {
            return .orange
        } else {
            return Color(red: 0.7, green: 0.29, blue: 0)
        }
    }

    private let errorMaxWidth: CGFloat = 320

    init(state: WebRTCTalkbackState, errorMessage: String? = nil, action: @escaping () -> Void) {
        self.state = state
        self.errorMessage = errorMessage
        self.action = action
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.oneAndHalf) {
            if let errorMessage {
                Text(errorMessage)
                    .font(DesignSystem.Font.footnote)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DesignSystem.Spaces.two)
                    .padding(.vertical, DesignSystem.Spaces.oneAndHalf)
                    .haGlassBackground(
                        in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.two, style: .continuous),
                        isInteractive: false
                    )
                    .frame(maxWidth: errorMaxWidth)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
            }
            Button(action: action) {
                HStack(spacing: DesignSystem.Spaces.one) {
                    switch state {
                    case .idle:
                        Image(systemSymbol: .micFill)
                    case .connecting:
                        ProgressView()
                            .tint(.white)
                    case .talking:
                        Image(systemSymbol: .micSlashFill)
                        Text(L10n.CameraPlayer.Talkback.stop)
                    }
                }
                .font(state == .talking ? DesignSystem.Font.headline : DesignSystem.Font.title2)
                .foregroundStyle(.white)
                .frame(minWidth: buttonSize, minHeight: buttonSize)
                .padding(.horizontal, state == .talking ? DesignSystem.Spaces.three : .zero)
                .haGlassBackground(in: Capsule(), tint: state == .talking ? talkingTint : nil)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        }
        .animation(.easeInOut(duration: 0.2), value: state)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle:
            return L10n.CameraPlayer.Talkback.start
        case .connecting:
            return L10n.CameraPlayer.Talkback.connecting
        case .talking:
            return L10n.CameraPlayer.Talkback.stop
        }
    }
}

#if DEBUG
#Preview {
    ZStack(alignment: .bottom) {
        LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)
        HStack(spacing: DesignSystem.Spaces.two) {
            WebRTCTalkbackButton(state: .idle, action: {})
            WebRTCTalkbackButton(state: .connecting, action: {})
            WebRTCTalkbackButton(state: .talking, action: {})
        }
        .padding(.bottom, DesignSystem.Spaces.three)
    }
    .preferredColorScheme(.dark)
}

#Preview("Error") {
    ZStack(alignment: .bottom) {
        LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)
        WebRTCTalkbackButton(
            state: .idle,
            errorMessage: L10n.CameraMicrophone.Errors.microphoneDenied,
            action: {}
        )
        .padding(.bottom, DesignSystem.Spaces.three)
    }
    .preferredColorScheme(.dark)
}
#endif

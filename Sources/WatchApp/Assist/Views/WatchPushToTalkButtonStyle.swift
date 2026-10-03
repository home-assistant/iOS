import SwiftUI

/// Drives a `Button` by press and release instead of by tap: `onPhaseChange` reports when a finger
/// lands on the label and whether it then lifted or the press was taken over by another gesture,
/// such as a scroll. Touch never runs the button's action, which stays reachable for the system, so
/// the Double Tap hand gesture and VoiceOver activation still perform it.
struct WatchPushToTalkButtonStyle: PrimitiveButtonStyle {
    enum Phase {
        /// A finger landed on the label.
        case began
        /// The finger lifted off the label.
        case released
        /// The press was taken over by another gesture before the finger lifted.
        case cancelled
    }

    let onPhaseChange: (Phase) -> Void

    func makeBody(configuration: Configuration) -> some View {
        PressTrackingLabel(configuration: configuration, onPhaseChange: onPhaseChange)
    }

    /// `@GestureState` needs a view's identity to live in, which the style struct does not have.
    private struct PressTrackingLabel: View {
        let configuration: PrimitiveButtonStyleConfiguration
        let onPhaseChange: (Phase) -> Void
        // Reset by SwiftUI when the gesture ends or is cancelled, which is the only signal a
        // cancellation gives: `onEnded` runs for a lift alone, so a reset without it is a cancel.
        @GestureState private var isPressing = false
        @State private var didRelease = false

        var body: some View {
            configuration.label
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isPressing) { _, isPressing, _ in
                            isPressing = true
                        }
                        .onEnded { _ in
                            didRelease = true
                        }
                )
                .onChange(of: isPressing) { isPressing in
                    if isPressing {
                        didRelease = false
                        onPhaseChange(.began)
                    } else {
                        onPhaseChange(didRelease ? .released : .cancelled)
                        didRelease = false
                    }
                }
        }
    }
}

#if DEBUG
#Preview {
    Button(action: {}, label: {
        Text(verbatim: "Hold me")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    })
    .buttonStyle(WatchPushToTalkButtonStyle(onPhaseChange: { _ in }))
}
#endif

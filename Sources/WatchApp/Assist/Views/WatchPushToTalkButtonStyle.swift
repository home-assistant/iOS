import SwiftUI

/// Drives a `Button` by press and release instead of by tap: `onPressingChanged` gets `true` when a
/// finger lands on the label and `false` when it lifts or the gesture is cancelled. Touch never runs
/// the button's action, which stays reachable for the system, so the Double Tap hand gesture and
/// VoiceOver activation still perform it.
struct WatchPushToTalkButtonStyle: PrimitiveButtonStyle {
    let onPressingChanged: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        PressTrackingLabel(configuration: configuration, onPressingChanged: onPressingChanged)
    }

    /// `@GestureState` needs a view's identity to live in, which the style struct does not have.
    private struct PressTrackingLabel: View {
        let configuration: PrimitiveButtonStyleConfiguration
        let onPressingChanged: (Bool) -> Void
        // Reset by SwiftUI when the gesture ends or is cancelled, so a press that a scroll takes
        // over still reports its release.
        @GestureState private var isPressing = false

        var body: some View {
            configuration.label
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isPressing) { _, isPressing, _ in
                            isPressing = true
                        }
                )
                .onChange(of: isPressing) { isPressing in
                    onPressingChanged(isPressing)
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
    .buttonStyle(WatchPushToTalkButtonStyle(onPressingChanged: { _ in }))
}
#endif

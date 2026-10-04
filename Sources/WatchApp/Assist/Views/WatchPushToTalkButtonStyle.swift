import SwiftUI

/// Drives a `Button` by press and release instead of by tap: `onPhaseChange` reports when a finger
/// lands on the label and whether it then lifted or the press was taken over by another gesture,
/// such as a scroll. Touch never runs the button's action, which stays reachable for the system, so
/// the Double Tap hand gesture and VoiceOver activation still perform it.
struct WatchPushToTalkButtonStyle: PrimitiveButtonStyle {
    enum Phase {
        /// A finger landed on the label at this time.
        case began(Date)
        /// The finger lifted off the label at this time.
        case released(Date)
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
        // The times are the touch events' own, so work holding the main thread between them does
        // not stretch or shorten the press. Reset by SwiftUI when the gesture ends or is cancelled,
        // which is the only signal a cancellation gives: `onEnded` runs for a lift alone, so a reset
        // without it is a cancel.
        @GestureState private var pressBegan: Date?
        @State private var releasedAt: Date?

        var body: some View {
            configuration.label
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($pressBegan) { value, pressBegan, _ in
                            // The first event of the press is the touch-down.
                            if pressBegan == nil {
                                pressBegan = value.time
                            }
                        }
                        .onEnded { value in
                            releasedAt = value.time
                        }
                )
                .onChange(of: pressBegan) { pressBegan in
                    if let pressBegan {
                        releasedAt = nil
                        onPhaseChange(.began(pressBegan))
                    } else if let releasedAt {
                        self.releasedAt = nil
                        onPhaseChange(.released(releasedAt))
                    } else {
                        onPhaseChange(.cancelled)
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

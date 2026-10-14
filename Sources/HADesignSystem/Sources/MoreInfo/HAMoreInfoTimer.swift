#if !os(watchOS)
import SwiftUI

/// A timer's more-info dialog: the time left, a duration to start it with, and the actions its state
/// allows. The SwiftUI counterpart of the frontend's `more-info-timer`.
public struct HAMoreInfoTimer: View {
    /// The timer's state, which decides the actions on offer.
    public enum Status: String, CaseIterable, Sendable {
        case idle
        case active
        case paused
    }

    private let display: String
    private let lastChanged: Date
    private let now: Date
    private let state: Status
    private let onStart: () -> Void
    private let onPause: () -> Void
    private let onResume: () -> Void
    private let onCancel: () -> Void
    private let onFinish: () -> Void
    @Binding private var duration: HATimeComponents

    /// - Parameters:
    ///   - display: The header: the time remaining while running, else the state.
    ///   - duration: What "Start" and "Set" start the timer with.
    ///   - onStart: Starts the timer with `duration`: idle's "Start", and "Set" while running.
    ///   - onResume: Paused's "Start", which carries on rather than starting over.
    public init(
        display: String,
        lastChanged: Date,
        now: Date,
        state: Status,
        duration: Binding<HATimeComponents>,
        onStart: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.display = display
        self.lastChanged = lastChanged
        self.now = now
        self.state = state
        _duration = duration
        self.onStart = onStart
        self.onPause = onPause
        self.onResume = onResume
        self.onCancel = onCancel
        self.onFinish = onFinish
    }

    private var strings: HADesignSystemEnvironment.Strings { HADesignSystemEnvironment.current.strings }

    public var body: some View {
        HAMoreInfoLayout {
            HAMoreInfoStateHeader(state: display, lastChanged: lastChanged, now: now)
        } controls: {
            HADurationInput(value: $duration, required: true)
                .fixedSize()
            HStack(spacing: DesignSystem.Spaces.one) {
                switch state {
                case .idle:
                    Button(strings.timerStart, action: onStart)
                case .active:
                    Button(strings.timerSet, action: onStart)
                    Button(strings.timerPause, action: onPause)
                case .paused:
                    Button(strings.timerSet, action: onStart)
                    Button(strings.timerStart, action: onResume)
                }
                if state != .idle {
                    Button(strings.timerCancel, action: onCancel)
                    Button(strings.timerFinish, action: onFinish)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.haPrimary)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignSystem.Spaces.four) {
            ForEach(HAMoreInfoTimer.Status.allCases, id: \.self) { state in
                HAMoreInfoTimer(
                    display: state == .idle ? "Idle" : "0:04:59",
                    lastChanged: Date(timeIntervalSinceNow: -1500),
                    now: Date(),
                    state: state,
                    duration: .constant(HATimeComponents(minutes: 5)),
                    onStart: {},
                    onPause: {},
                    onResume: {},
                    onCancel: {},
                    onFinish: {}
                )
            }
        }
        .padding(DesignSystem.Spaces.three)
    }
}

extension HAMoreInfoTimer: FrontendComponent {
    public static var frontendComponentName: String { "more-info-timer" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif

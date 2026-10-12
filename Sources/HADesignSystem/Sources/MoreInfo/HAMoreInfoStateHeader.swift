#if !os(watchOS)
import SwiftUI

/// The big state at the top of a more-info dialog and, under it, when it last changed. The SwiftUI
/// counterpart of the frontend's `ha-more-info-state-header`.
///
/// Tapping the time swaps the relative phrase for the absolute date and back. Both instants are
/// passed in, as ``HARelativeTime`` takes them, so the header renders the same way twice.
public struct HAMoreInfoStateHeader<Accessory: View>: View {
    private let state: String
    private let lastChanged: Date
    private let now: Date
    private let accessory: Accessory
    @State private var showsAbsoluteTime = false

    /// - Parameter accessory: Pinned to the trailing edge of the time row, the frontend's
    ///   `after-time` slot, where vacuums and mowers put their battery.
    public init(
        state: String,
        lastChanged: Date,
        now: Date,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.state = state
        self.lastChanged = lastChanged
        self.now = now
        self.accessory = accessory()
    }

    public var body: some View {
        VStack(spacing: .zero) {
            Text(state)
                .font(.system(size: 36))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            ZStack(alignment: .trailing) {
                Button {
                    showsAbsoluteTime.toggle()
                } label: {
                    Group {
                        if showsAbsoluteTime {
                            HAAbsoluteTime(date: lastChanged, now: now)
                        } else {
                            HARelativeTime(date: lastChanged, now: now)
                        }
                    }
                    .font(.system(size: 16, weight: .medium))
                    .padding(.vertical, DesignSystem.Spaces.half)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                accessory
            }
        }
        .padding(.bottom, DesignSystem.Spaces.two + DesignSystem.Spaces.half)
        .frame(maxWidth: .infinity)
    }
}

public extension HAMoreInfoStateHeader where Accessory == EmptyView {
    init(state: String, lastChanged: Date, now: Date) {
        self.init(state: state, lastChanged: lastChanged, now: now) { EmptyView() }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.three) {
        HAMoreInfoStateHeader(state: "On", lastChanged: Date(timeIntervalSinceNow: -2040), now: Date())
        HAMoreInfoStateHeader(state: "Docked", lastChanged: Date(timeIntervalSinceNow: -60), now: Date()) {
            HAMoreInfoBattery(level: 84, isCharging: true)
        }
    }
    .padding()
}

extension HAMoreInfoStateHeader: FrontendComponent {
    public static var frontendComponentName: String { "ha-more-info-state-header" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif

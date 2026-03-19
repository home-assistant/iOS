import ActivityKit
import Shared
import SwiftUI
import WidgetKit

// MARK: - DynamicIsland builder

/// Builds the `DynamicIsland` for a Home Assistant Live Activity.
/// Used in `HALiveActivityConfiguration`'s `dynamicIsland:` closure.
@available(iOS 16.2, *)
func makeHADynamicIsland(
    attributes: HALiveActivityAttributes,
    state: HALiveActivityAttributes.ContentState
) -> DynamicIsland {
    DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
            HADynamicIslandIconView(slug: state.icon, color: state.color, size: 24)
                .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.center) {
            Text(attributes.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.trailing) {
            HAExpandedTrailingView(state: state)
                .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
            HAExpandedBottomView(state: state)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
    } compactLeading: {
        HADynamicIslandIconView(slug: state.icon, color: state.color, size: 16)
            .padding(.leading, 4)
    } compactTrailing: {
        HACompactTrailingView(state: state)
            .padding(.trailing, 4)
    } minimal: {
        HADynamicIslandIconView(slug: state.icon, color: state.color, size: 14)
    }
}

// MARK: - Icon view

@available(iOS 16.2, *)
struct HADynamicIslandIconView: View {
    let slug: String?
    let color: String?
    let size: CGFloat

    var body: some View {
        if let slug, let mdiIcon = MaterialDesignIcons(serversideValueNamed: slug) {
            // UIColor(hex:) from Shared handles nil/CSS names/3-6-8 digit hex; non-failable.
            let uiColor = UIColor(hex: color ?? haBlueHex)
            Image(uiImage: mdiIcon.image(
                ofSize: .init(width: size, height: size),
                color: uiColor
            ))
            .resizable()
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Compact trailing

@available(iOS 16.2, *)
struct HACompactTrailingView: View {
    let state: HALiveActivityAttributes.ContentState

    var body: some View {
        if state.chronometer == true, let end = state.countdownEnd {
            Text(timerInterval: Date.now ... end, countsDown: true)
                .font(.caption2)
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(maxWidth: 50)
        } else if let critical = state.criticalText {
            Text(critical)
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: 50)
        } else if let fraction = state.progressFraction {
            Text("\(Int(fraction * 100))%")
                .font(.caption2)
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

// MARK: - Expanded trailing

@available(iOS 16.2, *)
struct HAExpandedTrailingView: View {
    let state: HALiveActivityAttributes.ContentState

    var body: some View {
        if let fraction = state.progressFraction {
            Text("\(Int(fraction * 100))%")
                .font(.caption2)
                .foregroundStyle(.white)
                .monospacedDigit()
        } else if let critical = state.criticalText {
            Text(critical)
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}

// MARK: - Expanded bottom

@available(iOS 16.2, *)
struct HAExpandedBottomView: View {
    let state: HALiveActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 4) {
            if state.chronometer == true, let end = state.countdownEnd {
                Text(timerInterval: Date.now ... end, countsDown: true)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.white)
            } else {
                Text(state.message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }

            if let fraction = state.progressFraction {
                ProgressView(value: fraction)
                    .tint(Color(hex: state.color ?? haBlueHex))
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 16.2, *)
#Preview("Compact", as: .dynamicIsland(.compact), using: HALiveActivityAttributes(tag: "washer", title: "Washer")) {
    HALiveActivityConfiguration()
} contentStates: {
    HALiveActivityAttributes.ContentState(
        message: "45 min remaining",
        criticalText: "45 min",
        progress: 2700,
        progressMax: 3600,
        icon: "mdi:washing-machine",
        color: "#2196F3"
    )
}

@available(iOS 16.2, *)
#Preview(
    "Expanded",
    as: .dynamicIsland(.expanded),
    using: HALiveActivityAttributes(tag: "washer", title: "Washing Machine")
) {
    HALiveActivityConfiguration()
} contentStates: {
    HALiveActivityAttributes.ContentState(
        message: "Cycle in progress",
        criticalText: "45 min",
        progress: 2700,
        progressMax: 3600,
        icon: "mdi:washing-machine",
        color: "#2196F3"
    )
}

@available(iOS 16.2, *)
#Preview("Minimal", as: .dynamicIsland(.minimal), using: HALiveActivityAttributes(tag: "washer", title: "Washer")) {
    HALiveActivityConfiguration()
} contentStates: {
    HALiveActivityAttributes.ContentState(
        message: "Running",
        icon: "mdi:washing-machine",
        color: "#2196F3"
    )
}
#endif

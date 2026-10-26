#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared
import SwiftUI
import WidgetKit

/// Builds the `DynamicIsland` for a Home Assistant Live Activity.
/// Used in `HALiveActivityConfiguration`'s `dynamicIsland:` closure.
///
/// The expanded presentation uses the bottom region alone: it spans the island's full width, which
/// is what keeps every row on one leading edge (see `HAExpandedContentView`).
@available(iOS 17.2, *)
func makeHADynamicIsland(
    attributes: HALiveActivityAttributes,
    state: HALiveActivityAttributes.ContentState
) -> DynamicIsland {
    DynamicIsland {
        DynamicIslandExpandedRegion(.bottom) {
            HAExpandedContentView(attributes: attributes, state: state)
        }
    } compactLeading: {
        HACompactLeadingView(state: state)
    } compactTrailing: {
        HACompactTrailingView(state: state)
    } minimal: {
        HADynamicIslandIconView(slug: state.icon, color: state.color, size: 16)
    }
}

@available(iOS 17.2, *)
private let previewAttributes = HALiveActivityAttributes(tag: "preview", title: "Laundry")

@available(iOS 17.2, *)
private let previewProgressState = HALiveActivityAttributes.ContentState(
    message: "Washing cycle",
    progress: 40,
    progressMax: 100,
    icon: "washing-machine",
    color: "#03A9F4"
)

@available(iOS 17.2, *)
private let previewTimerState = HALiveActivityAttributes.ContentState(
    message: "Pasta",
    chronometer: true,
    countdownEnd: Current.date().addingTimeInterval(12013),
    icon: "timer",
    color: "#FF9800"
)

@available(iOS 17.2, *)
private let previewCountUpState = HALiveActivityAttributes.ContentState(
    message: "Workout",
    chronometer: true,
    countdownEnd: Current.date().addingTimeInterval(-754),
    icon: "run",
    color: "#4CAF50"
)

@available(iOS 17.2, *)
private let previewCriticalState = HALiveActivityAttributes.ContentState(
    message: "Charging paused",
    criticalText: "03:20:13",
    icon: "battery-alert",
    color: "#F44336"
)

@available(iOS 17.2, *)
#Preview("Compact", as: .dynamicIsland(.compact), using: previewAttributes) {
    HALiveActivityConfiguration()
} contentStates: {
    previewProgressState
    previewTimerState
    previewCountUpState
    previewCriticalState
}

@available(iOS 17.2, *)
#Preview("Expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
    HALiveActivityConfiguration()
} contentStates: {
    previewProgressState
    previewTimerState
    previewCountUpState
    previewCriticalState
}

@available(iOS 17.2, *)
#Preview("Minimal", as: .dynamicIsland(.minimal), using: previewAttributes) {
    HALiveActivityConfiguration()
} contentStates: {
    previewProgressState
    previewTimerState
    previewCountUpState
    previewCriticalState
}
#endif

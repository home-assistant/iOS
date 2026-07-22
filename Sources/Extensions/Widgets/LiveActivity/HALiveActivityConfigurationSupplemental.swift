#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct HALiveActivityConfigurationSupplemental: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HALiveActivityAttributes.self) { context in
            HALiveActivityLockScreenRouterView(attributes: context.attributes, state: context.state)
                .haLiveActivitySupplementalChrome(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            makeHADynamicIsland(attributes: context.attributes, state: context.state)
                .widgetURL(haLiveActivityTapURL(attributes: context.attributes, state: context.state))
        }
        .supplementalActivityFamilies([.small])
    }
}

@available(iOS 18.0, *)
#Preview(
    "Lock Screen & Smart Stack",
    as: .content,
    using: HALiveActivityAttributes(tag: "preview", title: "Laundry")
) {
    HALiveActivityConfigurationSupplemental()
} contentStates: {
    HALiveActivityAttributes.ContentState(
        message: "Washing cycle",
        progress: 40,
        progressMax: 100,
        icon: "washing-machine",
        color: "#03A9F4"
    )
    HALiveActivityAttributes.ContentState(
        message: "Pasta",
        chronometer: true,
        countdownEnd: Current.date().addingTimeInterval(1500),
        icon: "timer",
        color: "#FF9800"
    )
    HALiveActivityAttributes.ContentState(
        message: "Charging paused",
        criticalText: "20%",
        icon: "battery-alert",
        color: "#F44336"
    )
}

@available(iOS 18.0, *)
#Preview(
    "Dynamic Island",
    as: .dynamicIsland(.expanded),
    using: HALiveActivityAttributes(tag: "preview", title: "Laundry")
) {
    HALiveActivityConfigurationSupplemental()
} contentStates: {
    HALiveActivityAttributes.ContentState(
        message: "Washing cycle",
        progress: 40,
        progressMax: 100,
        icon: "washing-machine",
        color: "#03A9F4"
    )
}
#endif

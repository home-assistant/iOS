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
                .haLiveActivityLockScreenChrome(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            makeHADynamicIsland(attributes: context.attributes, state: context.state)
                .widgetURL(haLiveActivityTapURL(attributes: context.attributes, state: context.state))
        }
        .supplementalActivityFamilies([.small])
    }
}
#endif

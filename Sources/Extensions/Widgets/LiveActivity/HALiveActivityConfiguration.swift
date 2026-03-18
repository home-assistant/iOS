import ActivityKit
import Shared
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct HALiveActivityConfiguration: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HALiveActivityAttributes.self) { context in
            HALockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Color.black.opacity(0.75))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            makeHADynamicIsland(attributes: context.attributes, state: context.state)
        }
    }
}

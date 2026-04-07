import ActivityKit
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17.2, *)
struct HALiveActivityConfiguration: Widget {
    /// Semi-transparent dark background for the Lock Screen presentation.
    private static let lockScreenBackground = Color.black.opacity(0.75)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HALiveActivityAttributes.self) { context in
            HALockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Self.lockScreenBackground)
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            makeHADynamicIsland(attributes: context.attributes, state: context.state)
        }
    }
}

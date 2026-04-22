#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17.2, *)
struct HALiveActivityConfiguration: Widget {
    /// Adaptive Lock Screen surface that matches the current system appearance.
    private static let lockScreenBackground = Color(uiColor: .systemBackground)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HALiveActivityAttributes.self) { context in
            HALockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Self.lockScreenBackground)
            .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            makeHADynamicIsland(attributes: context.attributes, state: context.state)
        }
    }
}
#endif

#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct HALiveActivityLockScreenRouterView: View {
    @Environment(\.activityFamily) private var activityFamily
    let attributes: HALiveActivityAttributes
    let state: HALiveActivityAttributes.ContentState

    var body: some View {
        switch activityFamily {
        case .small:
            HALiveActivityCompactView(attributes: attributes, state: state)
        case .medium:
            HALockScreenView(attributes: attributes, state: state)
        @unknown default:
            HALockScreenView(attributes: attributes, state: state)
        }
    }
}
#endif

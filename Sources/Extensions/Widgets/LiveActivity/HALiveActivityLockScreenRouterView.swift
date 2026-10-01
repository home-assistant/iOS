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
        content
            .activityBackgroundTint(backgroundTint)
            .activitySystemActionForegroundColor(foregroundColor)
            .widgetURL(haLiveActivityTapURL(attributes: attributes, state: state))
    }

    @ViewBuilder
    private var content: some View {
        switch activityFamily {
        case .small:
            HALiveActivityCompactView(attributes: attributes, state: state)
        case .medium:
            HALockScreenView(attributes: attributes, state: state)
        @unknown default:
            HALockScreenView(attributes: attributes, state: state)
        }
    }

    /// Background tint resolved per activity family. The Smart Stack / CarPlay (`.small`) family has
    /// no translucent Lock Screen material behind it, so it needs an opaque fill to stay legible;
    /// the Lock Screen (`.medium`) keeps the transparent, appearance-adaptive default.
    private var backgroundTint: Color {
        switch activityFamily {
        case .small:
            HAActivityVisualStyle.supplementalBackgroundColor(from: state.backgroundColor)
        default:
            HAActivityVisualStyle.backgroundColor(from: state.backgroundColor)
        }
    }

    /// Matches `backgroundTint`: the opaque `.small` background wants a guaranteed-legible default
    /// foreground, while `.medium` falls back to the adaptive system color over the Lock Screen material.
    private var foregroundColor: Color? {
        switch activityFamily {
        case .small:
            haLiveActivitySupplementalForegroundColor(for: state)
        default:
            haLiveActivityForegroundColor(for: state)
        }
    }
}
#endif

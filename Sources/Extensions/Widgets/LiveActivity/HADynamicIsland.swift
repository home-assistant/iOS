#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared
import SwiftUI
import WidgetKit

/// Builds the `DynamicIsland` for a Home Assistant Live Activity.
/// Used in `HALiveActivityConfiguration`'s `dynamicIsland:` closure.
///
/// The expanded regions carry only what the content state has to show and add no padding of their
/// own, so the system's uniform content margins keep them on one leading edge and an empty region
/// costs no height.
@available(iOS 17.2, *)
func makeHADynamicIsland(
    attributes: HALiveActivityAttributes,
    state: HALiveActivityAttributes.ContentState
) -> DynamicIsland {
    DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
            HADynamicIslandIconContainerView(slug: state.icon, color: state.color)
        }
        DynamicIslandExpandedRegion(.center) {
            HAExpandedCenterView(attributes: attributes, state: state)
        }
        DynamicIslandExpandedRegion(.trailing) {
            HAExpandedTrailingView(state: state)
        }
        DynamicIslandExpandedRegion(.bottom) {
            HAExpandedBottomView(state: state)
        }
    } compactLeading: {
        HADynamicIslandIconView(slug: state.icon, color: state.color, size: 18)
            .padding(.leading, DesignSystem.Spaces.half)
    } compactTrailing: {
        HACompactTrailingView(state: state)
            .padding(.trailing, DesignSystem.Spaces.half)
    } minimal: {
        HADynamicIslandIconView(slug: state.icon, color: state.color, size: 16)
    }
}
#endif

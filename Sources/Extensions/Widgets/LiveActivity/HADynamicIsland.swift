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

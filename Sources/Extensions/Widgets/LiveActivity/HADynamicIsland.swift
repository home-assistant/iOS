#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Shared
import SwiftUI
import WidgetKit

/// Builds the `DynamicIsland` for a Home Assistant Live Activity.
/// Used in `HALiveActivityConfiguration`'s `dynamicIsland:` closure.
@available(iOS 17.2, *)
func makeHADynamicIsland(
    attributes: HALiveActivityAttributes,
    state: HALiveActivityAttributes.ContentState
) -> DynamicIsland {
    DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
            HADynamicIslandIconContainerView(slug: state.icon, color: state.color, size: 28)
                .padding(.leading, DesignSystem.Spaces.one)
        }
        DynamicIslandExpandedRegion(.center) {
            Text(state.title ?? attributes.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        DynamicIslandExpandedRegion(.trailing) {
            HAExpandedTrailingView(state: state)
                .padding(.trailing, DesignSystem.Spaces.one)
        }
        DynamicIslandExpandedRegion(.bottom) {
            HAExpandedBottomView(state: state)
                .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
                .padding(.bottom, DesignSystem.Spaces.one)
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

#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// The whole expanded Dynamic Island body, laid out in one region so the icon, the text and the
/// progress bar share a single content inset. Split across the leading, center and trailing
/// regions they do not: the system insets each region differently and drops center content below
/// the TrueDepth camera, which staggers the rows.
@available(iOS 17.2, *)
struct HAExpandedContentView: View {
    let attributes: HALiveActivityAttributes
    let state: HALiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.oneAndHalf) {
            HStack(spacing: DesignSystem.Spaces.one) {
                HADynamicIslandIconContainerView(slug: state.icon, color: state.color)
                HAExpandedTitleView(attributes: attributes, state: state)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HAExpandedTrailingView(state: state)
            }
            HAExpandedBottomView(state: state)
        }
        .padding([.horizontal, .bottom], DesignSystem.Spaces.one)
    }
}

@available(iOS 17.2, *)
#Preview {
    HAExpandedContentView(
        attributes: .init(tag: "preview", title: "Laundry"),
        state: .init(
            message: "Washing cycle",
            progress: 40,
            progressMax: 100,
            icon: "washing-machine",
            color: "#03A9F4"
        )
    )
    .padding(DesignSystem.Spaces.two)
    .background(.black)
}
#endif

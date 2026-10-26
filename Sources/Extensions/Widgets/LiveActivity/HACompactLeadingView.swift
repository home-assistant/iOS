#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Leading slot of the compact Dynamic Island: the activity icon.
@available(iOS 17.2, *)
struct HACompactLeadingView: View {
    let state: HALiveActivityAttributes.ContentState

    @Environment(\.haIsDynamicIslandLimitedInWidth) private var isLimitedInWidth

    private static let iconSize: CGFloat = 18

    var body: some View {
        // The inset clears the island's rounded end. A narrow island (iPhone Duo, landscape, or one
        // shared with another activity) gives the slot a 28pt circle instead, where the inset would
        // push the icon off its centre.
        HADynamicIslandIconView(slug: state.icon, color: state.color, size: Self.iconSize)
            .padding(.leading, isLimitedInWidth ? 0 : DesignSystem.Spaces.half)
    }
}

@available(iOS 17.2, *)
#Preview {
    HACompactLeadingView(state: .init(message: "Washing cycle", icon: "washing-machine", color: "#03A9F4"))
        .padding(DesignSystem.Spaces.two)
        .background(.black)
}
#endif

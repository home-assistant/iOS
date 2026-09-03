#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Title and message block of the expanded Dynamic Island. The message is dropped when the
/// content state has none.
@available(iOS 17.2, *)
struct HAExpandedTitleView: View {
    let attributes: HALiveActivityAttributes
    let state: HALiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
            Text(state.title ?? attributes.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            if !state.message.isEmpty {
                Text(state.message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 17.2, *)
#Preview {
    HAExpandedTitleView(
        attributes: .init(tag: "preview", title: "Laundry"),
        state: .init(message: "Washing cycle", progress: 40, progressMax: 100, icon: "washing-machine")
    )
    .padding(DesignSystem.Spaces.two)
    .background(.black)
}
#endif

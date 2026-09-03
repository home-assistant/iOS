#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Center slot of the expanded Dynamic Island: the title, with the message underneath when the
/// content state carries one.
@available(iOS 17.2, *)
struct HAExpandedCenterView: View {
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
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 17.2, *)
#Preview {
    HAExpandedCenterView(
        attributes: .init(tag: "preview", title: "Laundry"),
        state: .init(message: "Washing cycle", progress: 40, progressMax: 100, icon: "washing-machine")
    )
    .padding(DesignSystem.Spaces.two)
    .background(.black)
}
#endif

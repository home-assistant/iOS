#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

@available(iOS 17.2, *)
struct HADynamicIslandIconContainerView: View {
    let slug: String?
    let color: String?

    private static let iconSize: CGFloat = 24

    var body: some View {
        if let slug {
            HADynamicIslandIconView(slug: slug, color: color, size: Self.iconSize)
                .padding(DesignSystem.Spaces.one)
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf, style: .continuous)
                        .fill(accentColor.opacity(0.2))
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf, style: .continuous)
                                .strokeBorder(accentColor.opacity(0.28))
                        }
                }
        }
    }

    private var accentColor: Color {
        HAActivityVisualStyle.color(from: color)
    }
}

@available(iOS 17.2, *)
#Preview {
    HADynamicIslandIconContainerView(slug: "washing-machine", color: "#03A9F4")
        .padding(DesignSystem.Spaces.two)
        .background(.black)
}
#endif

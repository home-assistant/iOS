#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

@available(iOS 17.2, *)
struct HADynamicIslandIconContainerView: View {
    let slug: String?
    let color: String?
    let size: CGFloat

    var body: some View {
        if slug != nil {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf, style: .continuous)
                    .fill(accentColor.opacity(0.2))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf, style: .continuous)
                            .strokeBorder(accentColor.opacity(0.28))
                    }

                HADynamicIslandIconView(slug: slug, color: color, size: size)
            }
            .frame(width: 44, height: 44)
        }
    }

    private var accentColor: Color {
        HAActivityVisualStyle.color(from: color)
    }
}

@available(iOS 17.2, *)
#Preview {
    HADynamicIslandIconContainerView(slug: "washing-machine", color: "#03A9F4", size: 28)
        .padding(DesignSystem.Spaces.two)
        .background(.black)
}
#endif

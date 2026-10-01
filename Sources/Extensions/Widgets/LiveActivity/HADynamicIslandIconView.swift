#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

@available(iOS 17.2, *)
struct HADynamicIslandIconView: View {
    let slug: String?
    let color: String?
    let size: CGFloat

    var body: some View {
        if let slug {
            // UIColor(hex:) from Shared handles nil/CSS names/3-6-8 digit hex; non-failable.
            let uiColor = HAActivityVisualStyle.uiColor(from: color)
            let mdiIcon = MaterialDesignIcons(serversideValueNamed: slug)
            Image(uiImage: mdiIcon.image(
                ofSize: .init(width: size, height: size),
                color: uiColor
            ))
            .resizable()
            .frame(width: size, height: size)
        }
    }
}

@available(iOS 17.2, *)
#Preview {
    HADynamicIslandIconView(slug: "washing-machine", color: "#03A9F4", size: 18)
        .padding(DesignSystem.Spaces.two)
        .background(.black)
}
#endif

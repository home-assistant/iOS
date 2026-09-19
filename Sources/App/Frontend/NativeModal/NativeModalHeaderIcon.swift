import Shared
import SwiftUI

/// An MDI icon named by the frontend (`mdi:chart-box-outline`), drawn as a template so the bar tints it.
struct NativeModalHeaderIcon: View {
    let name: String

    var body: some View {
        Image(
            uiImage: MaterialDesignIcons(serversideValueNamed: name, fallback: .helpCircleOutlineIcon)
                .image(ofSize: CGSize(width: 22, height: 22), color: nil)
        )
        .renderingMode(.template)
    }
}

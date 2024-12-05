import Shared
import SwiftUI

struct AppleLikeListTopRowHeader: View {
    let image: Image
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: .zero) {
            image
                .frame(maxWidth: .infinity, alignment: .center)
            Text(title)
                .font(.title3.bold())
                .padding(.bottom, Spaces.one)
            Text(subtitle)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom)
        }
    }
}

#Preview {
    AppleLikeListTopRowHeader(
        image: Image(imageAsset: Asset.SharedAssets.casita),
        title: "Settings",
        subtitle: "This is a text that represents the body"
    )
}

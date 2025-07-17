import SwiftUI

enum InformationViewConstants {
    static let iconSize: CGSize = .init(width: 28, height: 28)
}

public struct HABannerView<Icon: View>: View {

    private let icon: Icon
    private let text: String

    public init(
        @ViewBuilder icon: () -> Icon,
        text: String
    ) {
        self.icon = icon()
        self.text = text
    }

    public var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
            if let icon = icon as? Image {
                icon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: InformationViewConstants.iconSize.width,
                        height: InformationViewConstants.iconSize.height
                    )
            } else {
                icon
            }
            Text(text)
                .font(DesignSystem.Font.caption)
                .foregroundStyle(.secondary)
        }
        .padding(DesignSystem.Spaces.two)
        .background(.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
    }
}

#Preview {
    VStack {
        HABannerView(icon: {
            Image(systemSymbol: .heart)
        }, text: "Your location will only be used to check if you are connected to your local network. It will not be shared with anyone.")
    }
    .padding()
}

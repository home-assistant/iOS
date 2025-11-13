import Shared
import SwiftUI

struct AppleLikeListTopRowHeader: View {
    let image: MaterialDesignIcons?
    let headerImageAlternativeView: AnyView?
    let title: String
    let subtitle: String?

    init(
        image: MaterialDesignIcons?,
        headerImageAlternativeView: AnyView? = nil,
        title: String,
        subtitle: String? = nil
    ) {
        self.image = image
        self.headerImageAlternativeView = headerImageAlternativeView
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            if let image {
                Image(uiImage: image.image(ofSize: .init(width: 80, height: 80), color: .haPrimary))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let headerImageAlternativeView {
                headerImageAlternativeView
            }
            VStack(spacing: DesignSystem.Spaces.half) {
                Text(title)
                    .font(.title3.bold())
                if let subtitle {
                    Text(subtitle)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spaces.half)
    }
}

#Preview {
    List {
        AppleLikeListTopRowHeader(
            image: .abTestingIcon,
            title: "Settings",
            subtitle: "This is a text that represents the body"
        )
    }
}

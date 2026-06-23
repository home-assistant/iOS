import Shared
import SwiftUI

struct AppleLikeListTopRowHeader<Content: View>: View {
    let image: MaterialDesignIcons?
    let headerImageAlternativeView: AnyView?
    let title: String
    let subtitle: String?
    let content: Content

    init(
        image: MaterialDesignIcons?,
        headerImageAlternativeView: AnyView? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.image = image
        self.headerImageAlternativeView = headerImageAlternativeView
        self.title = title
        self.subtitle = subtitle
        self.content = content()
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
            if Content.self != EmptyView.self {
                Divider()
                content
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, DesignSystem.Spaces.half)
    }
}

extension AppleLikeListTopRowHeader where Content == EmptyView {
    init(
        image: MaterialDesignIcons?,
        headerImageAlternativeView: AnyView? = nil,
        title: String,
        subtitle: String? = nil
    ) {
        self.init(
            image: image,
            headerImageAlternativeView: headerImageAlternativeView,
            title: title,
            subtitle: subtitle
        ) {
            EmptyView()
        }
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

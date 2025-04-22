import Shared
import SwiftUI

struct AppleLikeListTopRowHeader: View {
    let image: MaterialDesignIcons?
    let headerImageAlternativeView: AnyView?
    let title: String
    let subtitle: String

    init(image: MaterialDesignIcons?, headerImageAlternativeView: AnyView? = nil, title: String, subtitle: String) {
        self.image = image
        self.headerImageAlternativeView = headerImageAlternativeView
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: Spaces.two) {
            if let image {
                Image(uiImage: image.image(ofSize: .init(width: 80, height: 80), color: Asset.Colors.haPrimary.color))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let headerImageAlternativeView {
                headerImageAlternativeView
            }
            VStack(spacing: Spaces.half) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.vertical, Spaces.half)
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
    .removeTopListPadding()
}

extension List {
    func removeTopListPadding() -> some View {
        modify { view in
            if #available(iOS 17.0, *) {
                view.contentMargins(.top, .zero)
            } else {
                view
            }
        }
    }
}

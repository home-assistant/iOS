import Shared
import SwiftUI

struct WidgetCircularView: View {
    var icon: MaterialDesignIcons
    var title: String?

    private static func scaleLogo(logo: UIImage, size: CGFloat) -> UIImage {
        let canvas = CGSize(width: size, height: size)
        let format = logo.imageRendererFormat
        return UIGraphicsImageRenderer(size: canvas, format: format).image {
            _ in logo.draw(in: CGRect(origin: .zero, size: canvas))
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: icon.unicode)
                .font(.custom(MaterialDesignIcons.familyName, size: 24))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
            if let title {
                Text(verbatim: title)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                Image(uiImage: Self.scaleLogo(logo: Asset.logo.image, size: 10))
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(Circle())
    }
}

#Preview {
    HStack {
        WidgetCircularView(icon: .scriptTextIcon)
        WidgetCircularView(icon: .coffeeIcon, title: "Coffee")
        WidgetCircularView(icon: .lightbulbIcon, title: "Lights")
    }
}

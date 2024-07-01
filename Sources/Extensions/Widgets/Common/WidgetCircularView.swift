import Shared
import SwiftUI

struct WidgetCircularView: View {
    var icon: MaterialDesignIcons

    private static func scaleLogo(logo: UIImage, size: CGFloat) -> UIImage {
        let canvas = CGSize(width: size, height: size)
        let format = logo.imageRendererFormat
        return UIGraphicsImageRenderer(size: canvas, format: format).image {
            _ in logo.draw(in: CGRect(origin: .zero, size: canvas))
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(uiImage: icon.image(
                ofSize: .init(width: 24, height: 24),
                color: .white
            ))
            .foregroundStyle(.ultraThickMaterial)
            Image(uiImage: Self.scaleLogo(logo: Asset.SharedAssets.logo.image, size: 10))
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(Circle())
    }
}

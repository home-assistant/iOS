import Foundation
import Shared
import UIKit

/// Renders the Material Design icon an entity resolves to as PNG data for its Spotlight result.
///
/// Drawn in Home Assistant blue rather than black so the glyph stays visible in both light and dark
/// appearances (Spotlight shows the thumbnail as-is), and memoized by icon name because the same few
/// glyphs repeat across thousands of entities.
enum SpotlightEntityIconRenderer {
    static func thumbnailData(iconName: String) -> Data? {
        let key = iconName as NSString
        if let cached = cache.object(forKey: key) {
            return cached as Data
        }

        MaterialDesignIcons.register()
        let icon = MaterialDesignIcons(serversideValueNamed: iconName, fallback: .dotsGridIcon)
        let imageRect = CGRect(origin: .zero, size: size).insetBy(dx: 12, dy: 12)
        let data = UIGraphicsImageRenderer(size: size).pngData { _ in
            icon
                .image(ofSize: imageRect.size, color: AppConstants.lighterTintColor)
                .draw(in: imageRect)
        }

        cache.setObject(data as NSData, forKey: key)
        return data
    }

    private static let size = CGSize(width: 128, height: 128)
    private static let cache = NSCache<NSString, NSData>()
}

import UIKit

/// Memoizes the bitmaps behind `IconDrawable.image(ofSize:color:edgeInsets:)`, which rasterizes a glyph
/// through TextKit on every call. Callers ask for the same glyph repeatedly: a SwiftUI row re-renders for
/// reasons that have nothing to do with its icon (hover, selection), and lists draw the same handful of
/// icons at the same size for every row.
final class IconImageCache: @unchecked Sendable {
    static let shared = IconImageCache()

    private static let countLimit = 256
    private static let totalCostLimit = 2 * 1024 * 1024
    private static let fontProbeSize: CGFloat = 10

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = Self.countLimit
        cache.totalCostLimit = Self.totalCostLimit
    }

    func image(
        familyName: String,
        name: String,
        size: CGSize,
        color: UIColor?,
        edgeInsets: UIEdgeInsets,
        render: () -> UIImage
    ) -> UIImage {
        guard let key = Self.key(
            familyName: familyName,
            name: name,
            size: size,
            color: color,
            edgeInsets: edgeInsets
        ) else {
            return render()
        }

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let image = render()
        // Until the font is registered every glyph draws as the same missing-character box, and a cached one
        // of those would outlive the registration.
        guard UIFont(name: familyName, size: Self.fontProbeSize) != nil else { return image }
        cache.setObject(image, forKey: key, cost: Self.cost(of: image))
        return image
    }

    private static func key(
        familyName: String,
        name: String,
        size: CGSize,
        color: UIColor?,
        edgeInsets: UIEdgeInsets
    ) -> NSString? {
        guard let colorKey = colorKey(color) else { return nil }
        let insets = "\(edgeInsets.top),\(edgeInsets.left),\(edgeInsets.bottom),\(edgeInsets.right)"
        return "\(familyName)|\(name)|\(size.width)x\(size.height)|\(insets)|\(colorKey)" as NSString
    }

    /// Reading a dynamic color's components resolves it against the current trait collection, exactly as
    /// drawing the glyph does, so the resolved components are what the bitmap really depends on: keying on the
    /// color object would hand a light-mode bitmap back in dark mode. Nil (a pattern color, whose components
    /// cannot be read) skips the cache.
    private static func colorKey(_ color: UIColor?) -> String? {
        guard let color else { return "default" }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return "\(red),\(green),\(blue),\(alpha)"
        }
        var white: CGFloat = 0
        if color.getWhite(&white, alpha: &alpha) {
            return "w\(white),\(alpha)"
        }
        return nil
    }

    private static func cost(of image: UIImage) -> Int {
        let bytes = image.size.width * image.scale * image.size.height * image.scale * 4
        return bytes.isFinite ? Int(bytes) : 0
    }
}

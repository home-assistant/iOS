#if !os(watchOS)
import HAIconic
import SwiftUI
import UIKit

/// A Material Design icon as a template `Image`, so the caller tints it with `foregroundStyle`.
///
/// Lives in the design system rather than the app because every component that draws an MDI glyph
/// needs it, and rendering one is expensive enough to be worth caching in a single place.
public struct MaterialDesignIconsImage: View {
    private let icon: MaterialDesignIcons
    private let size: CGFloat

    public init(icon: MaterialDesignIcons, size: CGFloat) {
        self.icon = icon
        self.size = size
    }

    /// Rendered glyph bitmaps keyed by icon and size. Rendering goes through CoreText into a bitmap
    /// context, which is too slow to repeat for ~20 rows on every settings list body evaluation.
    /// The image is displayed as a template (only its alpha channel matters), so the cache doesn't
    /// need to vary by color or light/dark appearance.
    private static let renderedImageCache = NSCache<NSString, UIImage>()

    /// The font has to be registered before a glyph can be drawn. The app does it at launch, but
    /// previews and snapshot tests instantiate components without going through it, so registering
    /// here — `register()` returns early once the family is known — keeps them working.
    private static let fontRegistration: Void = MaterialDesignIcons.register()

    public var body: some View {
        Image(uiImage: Self.image(for: icon, size: size))
            .renderingMode(.template)
    }

    /// The same glyph as a bare `Image`, for the one thing a `View` cannot do: sit inside a `Text`.
    ///
    /// Concatenating into a `Text` is what lets an icon flow with the words around it and wrap with
    /// them, which is how the frontend's `ha-tip` reads. Everywhere else, use the view.
    public static func templateImage(icon: MaterialDesignIcons, size: CGFloat) -> Image {
        Image(uiImage: image(for: icon, size: size))
            .renderingMode(.template)
    }

    private static func image(for icon: MaterialDesignIcons, size: CGFloat) -> UIImage {
        let cacheKey = "\(icon.unicode)-\(size)" as NSString
        if let cached = renderedImageCache.object(forKey: cacheKey) {
            return cached
        }
        _ = fontRegistration
        let image = icon.image(ofSize: CGSize(width: size, height: size), color: .label)
        renderedImageCache.setObject(image, forKey: cacheKey)
        return image
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        MaterialDesignIconsImage(icon: .lightbulbOutlineIcon, size: 24)
        MaterialDesignIconsImage(icon: .alertOutlineIcon, size: 48)
            .foregroundStyle(.haWarningColor)
    }
}

extension MaterialDesignIconsImage: FrontendComponent {
    public static var frontendComponentName: String { "ha-svg-icon" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif

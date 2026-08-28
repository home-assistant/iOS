#if !os(watchOS)
import Foundation
import HAIconic
import SwiftUI

/// How much room a single tile has, which is what decides its typography and icon size.
///
/// Resolved from the widget family and the number of tiles by ``WidgetFamilyLayout``, so every
/// widget built out of tiles sizes them the same way.
public enum WidgetTileSizeStyle: CaseIterable, Sendable {
    case single
    case expanded
    case compact
    /// Minimum size possible for widget, removing padding and borders as well
    case compressed
    case regular

    public var textFont: Font {
        switch self {
        case .single, .expanded:
            return .subheadline
        case .compact, .regular:
            return .footnote
        case .compressed:
            return .caption
        }
    }

    public var subtextFont: Font {
        switch self {
        case .single, .expanded:
            return .footnote
        case .regular, .compact:
            return .caption
        case .compressed:
            return .caption2
        }
    }

    /// How much larger a glyph is drawn when it has no background behind it: with no circle to sit
    /// inside, the icon has the whole slot to itself and reads too small at the regular size.
    public static let iconScaleWithoutBackground: CGFloat = 1.5

    public var iconSize: CGFloat {
        switch self {
        case .single:
            return 32
        case .expanded:
            return 28
        case .regular, .compact:
            return 20
        case .compressed:
            return 15
        }
    }

    /// The size a glyph is drawn at, which depends on whether it has a circle behind it.
    public func iconSize(withBackground: Bool) -> CGFloat {
        withBackground ? iconSize : iconSize * Self.iconScaleWithoutBackground
    }

    public var iconFont: Font {
        iconFont(withBackground: true)
    }

    public func iconFont(withBackground: Bool) -> Font {
        .custom(MaterialDesignIcons.familyName, size: iconSize(withBackground: withBackground))
    }

    /// Icon circle background size
    public var iconCircleSize: CGSize {
        switch self {
        case .single:
            return .init(width: 48, height: 48)
        case .expanded:
            return .init(width: 42, height: 42)
        case .regular, .compact:
            return .init(width: 38, height: 38)
        case .compressed:
            return .init(width: 30, height: 30)
        }
    }
}
#endif

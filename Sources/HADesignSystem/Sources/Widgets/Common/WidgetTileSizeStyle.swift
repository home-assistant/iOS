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
    /// A compact tile in a row shorter than compact was drawn for — a page that spends part of its
    /// height on headings, say. Same card and same text, with the icon and the padding brought in so
    /// the glyph doesn't fill the tile and the text doesn't start miles from its edge.
    case dense
    /// Minimum size possible for widget, removing padding and borders as well
    case compressed
    case regular

    public var textFont: Font {
        switch self {
        case .single, .expanded:
            return .subheadline
        case .compact, .dense, .regular:
            return .footnote
        case .compressed:
            return .caption
        }
    }

    public var subtextFont: Font {
        switch self {
        case .single, .expanded:
            return .footnote
        case .regular, .compact, .dense:
            return .caption
        case .compressed:
            return .caption2
        }
    }

    /// Whether a tile drawn at this size has room for the area line above its name.
    ///
    /// A compressed tile has already given up its padding and its border to fit; a third line of
    /// text is the next thing to go, so the name and the state keep the room they have.
    public var showsAreaLine: Bool {
        self != .compressed
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
        case .dense:
            return 16
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

    /// How far a tile's contents sit from its leading and trailing edges.
    ///
    /// A dense tile pulls them in: the icon it draws is smaller, so the usual inset would leave the
    /// glyph floating away from the edge and the text starting further in than the tile is tall.
    public var horizontalPadding: CGFloat {
        self == .dense ? DesignSystem.Spaces.one : DesignSystem.Spaces.oneAndHalf
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
        case .dense:
            return .init(width: 30, height: 30)
        case .compressed:
            return .init(width: 30, height: 30)
        }
    }

    /// The icon slot in a row this tall: the row, less the inset it keeps above and below the icon —
    /// the same one it keeps at the leading edge, so the glyph is not pressed against the card's top
    /// and bottom while the text starts further in than the icon does.
    ///
    /// Never larger than the size the style is drawn at: a row with height to spare keeps the icon
    /// the design system sized it for rather than growing one to fill it. A row of no height is one
    /// nobody has measured, which is no reason to shrink anything.
    public func iconCircleSize(inRowOfHeight rowHeight: CGFloat?) -> CGSize {
        guard let rowHeight, rowHeight > .zero else { return iconCircleSize }
        let side = min(iconCircleSize.height, max(.zero, rowHeight - horizontalPadding * 2))
        return .init(width: side, height: side)
    }

    /// The size a glyph is drawn at in a row this tall: brought down in step with the slot it sits
    /// in, so a glyph fills the same share of its circle at every height.
    public func iconSize(withBackground: Bool, inRowOfHeight rowHeight: CGFloat?) -> CGFloat {
        let full = iconSize(withBackground: withBackground)
        guard iconCircleSize.height > .zero else { return full }
        return full * (iconCircleSize(inRowOfHeight: rowHeight).height / iconCircleSize.height)
    }

    public func iconFont(withBackground: Bool, inRowOfHeight rowHeight: CGFloat?) -> Font {
        .custom(
            MaterialDesignIcons.familyName,
            size: iconSize(withBackground: withBackground, inRowOfHeight: rowHeight)
        )
    }
}
#endif

#if !os(watchOS)
import Foundation
import HAIconic
import SwiftUI

/// Everything a single widget tile needs to draw itself.
///
/// Deliberately free of anything that makes a tile *do* something: what a tap runs belongs to the
/// widget that owns the tile, not to the component that renders it. See ``WidgetTileGridView`` for
/// how interaction is layered back on top.
public struct WidgetTileModel: Identifiable, Hashable {
    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        area: String? = nil,
        icon: MaterialDesignIcons,
        showIconBackground: Bool = true,
        textColor: Color = Color(uiColor: .label),
        iconColor: Color = Color.haPrimary,
        backgroundColor: Color = .widgetTileBackground,
        useCustomColors: Bool = false,
        disabled: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.area = area
        self.icon = icon
        self.showIconBackground = showIconBackground
        self.textColor = textColor
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
        self.useCustomColors = useCustomColors
        self.disabled = disabled
    }

    public var id: String
    public var title: String
    public var subtitle: String?
    /// The area the entity belongs to.
    ///
    /// Drawn as its own line above ``title``, the way Apple's Home tiles stack room, name and
    /// state, so none of the three has to share a line with the others and truncate the rest away.
    public var area: String?
    public var icon: MaterialDesignIcons
    /// When item has no tap icon, icon background is hidden
    public var showIconBackground: Bool
    public var backgroundColor: Color
    public var textColor: Color
    public var iconColor: Color
    public var useCustomColors: Bool
    /// When one item confirmation is pending, the rest of the items should be blurred
    public var disabled: Bool
}

/// Anything a ``WidgetTileGridView`` can lay out.
///
/// Widgets carry their own richer models — the intent to run, the confirmation state — so the grid
/// asks them for the presentation half rather than making them flatten to it first.
public protocol WidgetTileRepresentable: Identifiable, Hashable {
    var tileModel: WidgetTileModel { get }
}

extension WidgetTileModel: WidgetTileRepresentable {
    public var tileModel: WidgetTileModel { self }
}
#endif

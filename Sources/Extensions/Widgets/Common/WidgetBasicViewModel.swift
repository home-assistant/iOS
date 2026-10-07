import Foundation
import Shared
import SwiftUI

/// A widget tile plus what a tap on it runs.
///
/// The drawing half lives in the design system as ``WidgetTileModel``; this adds the half that only
/// the widget extension can act on — the intent or deep link behind the tile, and where it is in the
/// confirmation dance.
struct WidgetBasicViewModel: Identifiable, Hashable, Encodable {
    init(
        id: String,
        title: String,
        subtitle: String?,
        area: String? = nil,
        interactionType: WidgetInteractionType,
        iconInteractionType: WidgetInteractionType? = nil,
        icon: MaterialDesignIcons,
        showIconBackground: Bool = true,
        textColor: Color = Color(uiColor: .label),
        iconColor: Color = Color.haPrimary,
        backgroundColor: Color = .tileBackground,
        useCustomColors: Bool = false,
        showConfirmation: Bool = false,
        confirmsTapAction: Bool = false,
        requiresConfirmation: Bool = false,
        widgetId: String? = nil,
        disabled: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.area = area
        self.interactionType = interactionType
        self.iconInteractionType = iconInteractionType
        self.textColor = textColor
        self.icon = icon
        self.showIconBackground = showIconBackground
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
        self.useCustomColors = useCustomColors
        self.showConfirmation = showConfirmation
        self.confirmsTapAction = confirmsTapAction
        self.requiresConfirmation = requiresConfirmation
        self.widgetId = widgetId
        self.disabled = disabled
    }

    var id: String

    var title: String
    var subtitle: String?
    /// The area the entity belongs to, drawn above the name. See ``WidgetTileModel/area``.
    var area: String?
    var interactionType: WidgetInteractionType
    /// What tapping the tile's icon runs, when the icon is a control of its own and `interactionType`
    /// belongs to the rest of the tile. `nil` keeps the tile whole — one control, one tap.
    var iconInteractionType: WidgetInteractionType?

    var icon: MaterialDesignIcons
    /// When item has no tap icon, icon background is hidden
    var showIconBackground: Bool

    var backgroundColor: Color
    var textColor: Color
    var iconColor: Color
    var useCustomColors: Bool

    // When widget requires confirmation before execution this is true
    // and we show confirmation buttons instead of the widget item data
    var showConfirmation: Bool
    /// Which half the pending confirmation is for: the rest of a split tile (`interactionType`)
    /// when true, otherwise its icon — or the whole tile, when it isn't split.
    var confirmsTapAction: Bool
    // This will first display confirmation form
    // the intent of the forms in this button will run or not the real intent
    var requiresConfirmation: Bool

    /// Used to update confirmation state
    var widgetId: String?
    /// When one item confirmation is pending, the rest of the items should be blurred
    var disabled: Bool
}

extension WidgetBasicViewModel: WidgetTileRepresentable {
    var tileModel: WidgetTileModel {
        .init(
            id: id,
            title: title,
            subtitle: subtitle,
            area: area,
            icon: icon,
            showIconBackground: showIconBackground,
            textColor: textColor,
            iconColor: iconColor,
            backgroundColor: backgroundColor,
            useCustomColors: useCustomColors,
            disabled: disabled
        )
    }
}

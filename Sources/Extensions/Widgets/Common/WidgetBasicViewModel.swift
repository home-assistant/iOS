import Foundation
import Shared
import SwiftUI

struct WidgetBasicViewModel: Identifiable, Hashable, Encodable {
    init(
        id: String,
        title: String,
        subtitle: String?,
        interactionType: WidgetInteractionType,
        iconInteractionType: WidgetInteractionType,
        icon: MaterialDesignIcons,
        showIconBackground: Bool = true,
        textColor: Color = Color(uiColor: .label),
        iconColor: Color = Color.haPrimary,
        backgroundColor: Color = .tileBackground,
        useCustomColors: Bool = false,
        showConfirmation: Bool = false,
        requiresConfirmation: Bool = false,
        widgetId: String? = nil,
        disabled: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.interactionType = interactionType
        self.iconInteractionType = iconInteractionType
        self.textColor = textColor
        self.icon = icon
        self.showIconBackground = showIconBackground
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
        self.useCustomColors = useCustomColors
        self.showConfirmation = showConfirmation
        self.requiresConfirmation = requiresConfirmation
        self.widgetId = widgetId
        self.disabled = disabled
    }

    var id: String

    var title: String
    var subtitle: String?
    var interactionType: WidgetInteractionType
    var iconInteractionType: WidgetInteractionType

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
    // This will first display confirmation form
    // the intent of the forms in this button will run or not the real intent
    var requiresConfirmation: Bool

    /// Used to update confirmation state
    var widgetId: String?
    /// When one item confirmation is pending, the rest of the items should be blurred
    var disabled: Bool
}

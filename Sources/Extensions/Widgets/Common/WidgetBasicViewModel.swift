import Foundation
import Shared
import SwiftUI

struct WidgetBasicViewModel: Identifiable, Hashable, Encodable {
    init(
        id: String,
        title: String,
        subtitle: String?,
        interactionType: InteractionType,
        icon: MaterialDesignIcons,
        textColor: Color = Color(uiColor: .label),
        iconColor: Color = Color.asset(Asset.Colors.haPrimary),
        backgroundColor: Color = Color.asset(Asset.Colors.tileBackground),
        useCustomColors: Bool = false,
        showConfirmation: Bool = false,
        showProgress: Bool = false,
        progress: Int = 0,
        requiresConfirmation: Bool = false,
        widgetId: String? = nil,
        disabled: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.interactionType = interactionType
        self.textColor = textColor
        self.icon = icon
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
        self.useCustomColors = useCustomColors
        self.showConfirmation = showConfirmation
        self.showProgress = showProgress
        self.progress = progress
        self.requiresConfirmation = requiresConfirmation
        self.widgetId = widgetId
        self.disabled = disabled
    }

    var id: String

    var title: String
    var subtitle: String?
    var interactionType: InteractionType

    var icon: MaterialDesignIcons

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

    // When the widget item is executing it can display progress
    var showProgress: Bool
    var progress: Int

    /// Used to update confirmation state
    var widgetId: String?
    /// When one item confirmation is pending, the rest of the items should be blurred
    var disabled: Bool

    enum InteractionType: Hashable, Encodable {
        case widgetURL(URL)
        case appIntent(WidgetIntentType)
    }

    enum WidgetIntentType: Hashable, Encodable {
        case action(id: String, name: String)
        case script(id: String, entityId: String, serverId: String, name: String, showConfirmationNotification: Bool)
        /// Entities that can be toggled
        case toggle(
            widgetId: String,
            magicItemServerUniqueId: String,
            entityId: String,
            domain: String,
            serverId: String
        )
        /// Script or Scene
        case activate(entityId: String, domain: String, serverId: String)
        /// Button
        case press(entityId: String, domain: String, serverId: String)
        case refresh
    }
}

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
        useCustomColors: Bool = false
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

    enum InteractionType: Hashable, Encodable {
        case widgetURL(URL)
        case appIntent(WidgetIntentType)
    }

    enum WidgetIntentType: Hashable, Encodable {
        case action(id: String, name: String)
        case script(id: String, serverId: String, name: String, showConfirmationNotification: Bool)
    }
}

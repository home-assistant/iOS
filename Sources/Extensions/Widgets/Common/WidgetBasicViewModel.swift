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
        iconColor: Color = Color.black
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.interactionType = interactionType
        self.icon = icon
        self.iconColor = iconColor
    }

    var id: String

    var title: String
    var subtitle: String?
    var interactionType: InteractionType

    var icon: MaterialDesignIcons

    var iconColor: Color

    enum InteractionType: Hashable, Encodable {
        case widgetURL(URL)
        case appIntent(WidgetIntentType)
    }

    enum WidgetIntentType: Hashable, Encodable {
        case action(id: String, name: String)
    }
}

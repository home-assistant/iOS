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
        showsChevron: Bool = false,
        textColor: Color = Color.black,
        iconColor: Color = Color.black,
        backgroundColor: Color = Color.white
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.interactionType = interactionType
        self.textColor = textColor
        self.icon = icon
        self.showsChevron = showsChevron
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
    }

    var id: String

    var title: String
    var subtitle: String?
    var interactionType: InteractionType

    var icon: MaterialDesignIcons
    var showsChevron: Bool

    var backgroundColor: Color
    var textColor: Color
    var iconColor: Color

    enum InteractionType: Hashable, Encodable {
        case widgetURL(URL)
        case appIntent(WidgetIntentType)
    }

    enum WidgetIntentType: Hashable, Encodable {
        case action(id: String, name: String)
    }
}

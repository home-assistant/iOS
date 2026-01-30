import Foundation

public enum WidgetInteractionType: Hashable, Encodable {
    case widgetURL(URL)
    case appIntent(WidgetIntentType)
    /// No interaction, item is purely visual
    case noAction
}

public enum WidgetIntentType: Hashable, Encodable {
    case action(id: String, name: String)
    case script(id: String, entityId: String, serverId: String, name: String, showConfirmationNotification: Bool)
    /// Entities that can be toggled
    case toggle(entityId: String, domain: String, serverId: String)
    /// Script or Scene
    case activate(entityId: String, domain: String, serverId: String)
    /// Button
    case press(entityId: String, domain: String, serverId: String)
    case refresh
}

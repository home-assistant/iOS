import Foundation

public enum WidgetInteractionType: Hashable, Encodable {
    case widgetURL(URL)
    case appIntent(WidgetIntentType)
}

public enum WidgetIntentType: Hashable, Encodable {
    case script(id: String, entityId: String, serverId: String, name: String, showConfirmationNotification: Bool)
    /// Entities that can be toggled
    case toggle(entityId: String, domain: String, serverId: String)
    /// Script or Scene
    case activate(entityId: String, domain: String, serverId: String)
    /// Button
    case press(entityId: String, domain: String, serverId: String)
    /// A `domain.service` call with a JSON payload — the frontend's "perform action". `actionId` is
    /// the `domain.service` pair and `payload` the JSON object sent as the action's data.
    case performAction(serverId: String, actionId: String, payload: String)
    case refresh
}

import Foundation

public enum WidgetInteractionType: Hashable, Encodable {
    case widgetURL(URL)
    case appIntent(WidgetIntentType)

    /// Whether this only opens the entity's more-info dialog in the app — the one interaction a
    /// tile never asks to confirm, since it changes nothing.
    public var opensMoreInfoDialog: Bool {
        guard case let .widgetURL(url) = self,
              let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return false
        }
        return queryItems.contains { $0.name == AppConstants.QueryItems.openMoreInfoDialog.rawValue }
    }
}

public enum WidgetIntentType: Hashable, Encodable {
    case script(id: String, entityId: String, serverId: String, name: String, showConfirmationNotification: Bool)
    /// The frontend's "toggle": the domain's on or off service, picked from the entity's state —
    /// see `EntityToggler`. Only domains with such a pair (`Domain.canToggle`) get here.
    case toggle(entityId: String, domain: String, serverId: String)
    /// Runs the domain's main action outright: presses a button, activates a scene, runs a script,
    /// triggers an automation — the "run script" behavior, and an item's own "Press", "Activate",
    /// "Run" or "Trigger".
    case activate(entityId: String, domain: String, serverId: String)
    /// A `domain.service` call with a JSON payload — the frontend's "perform action". `actionId` is
    /// the `domain.service` pair and `payload` the JSON object sent as the action's data.
    case performAction(serverId: String, actionId: String, payload: String)
    case refresh
}

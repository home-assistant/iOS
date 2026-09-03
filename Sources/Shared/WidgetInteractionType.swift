import Foundation

public enum WidgetInteractionType: Hashable, Encodable {
    case widgetURL(URL)
    case appIntent(WidgetIntentType)

    /// Whether this only opens the entity in the app — its more-info dialog, or the native camera
    /// player a camera opens in instead — the one interaction a tile never asks to confirm, since
    /// it changes nothing.
    public var opensEntityInApp: Bool {
        guard case let .widgetURL(url) = self,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme,
              AppConstants.deeplinkSchemes.contains(scheme) else {
            return false
        }
        if components.host == AppConstants.cameraDeeplinkHost {
            return true
        }
        return components.queryItems?
            .contains { $0.name == AppConstants.QueryItems.openMoreInfoDialog.rawValue } == true
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

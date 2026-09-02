import Foundation

public extension Domain {
    /// The service that runs an entity of this domain outright, where that is something its toggle
    /// doesn't do: a script runs (`script.turn_on` — its toggle would stop one that is running),
    /// an automation triggers (`automation.trigger` — its toggle enables or disables it). `nil`
    /// for every other domain: a scene's or a button's toggle already activates or presses it,
    /// and the rest have nothing to run.
    var activateService: Service? {
        switch self {
        case .script:
            return .turnOn
        case .automation:
            return .trigger
        default:
            return nil
        }
    }

    /// What the customization screen calls `activateService`: "Run" for a script, "Trigger" for
    /// an automation.
    var activateActionName: String? {
        switch self {
        case .script:
            return L10n.Widgets.Action.Name.run
        case .automation:
            return L10n.Widgets.Action.Name.trigger
        default:
            return nil
        }
    }
}

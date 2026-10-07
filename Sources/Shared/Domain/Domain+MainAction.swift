import Foundation

public extension Domain {
    /// The domain's main action (`mainAction`) offered as a behavior of its own on the customization
    /// screen, where "toggle" doesn't already spell it out: press a button, activate a scene, run a
    /// script, trigger an automation. `nil` for a domain whose main action is the toggle itself —
    /// "Toggle" covers that — and for one with no main action at all.
    ///
    /// The frontend's "toggle" presses a button and activates a scene too, so those get both
    /// entries; a script's and an automation's toggle do something else (stop a running script,
    /// enable or disable the automation), which is why the main action is offered at all.
    var explicitMainAction: Service? {
        guard let mainAction, mainAction != .toggle else { return nil }
        return mainAction
    }

    /// What the customization screen calls `explicitMainAction`: "Press" for a button, "Activate"
    /// for a scene, "Run" for a script, "Trigger" for an automation.
    var mainActionName: String? {
        switch self {
        case .button, .inputButton:
            return L10n.Widgets.Action.Name.press
        case .scene:
            return L10n.Widgets.Action.Name.activate
        case .script:
            return L10n.Widgets.Action.Name.run
        case .automation:
            return L10n.Widgets.Action.Name.trigger
        default:
            return nil
        }
    }
}

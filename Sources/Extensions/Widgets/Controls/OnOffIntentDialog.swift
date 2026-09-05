import Foundation
import Shared

/// The spoken confirmation for the on/off/toggle control intents.
enum OnOffIntentDialog {
    static func text(entityName: String, toggle: Bool, value: Bool) -> String {
        if toggle {
            return L10n.AppIntents.Dialog.toggled(entityName)
        }
        return value
            ? L10n.AppIntents.Dialog.turnedOn(entityName)
            : L10n.AppIntents.Dialog.turnedOff(entityName)
    }
}

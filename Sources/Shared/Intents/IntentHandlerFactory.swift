import Foundation
import Intents

public enum IntentHandlerFactory {
    public static func handler(for intent: INIntent) -> Any {
        // Only the system Focus-status intent remains; the legacy SiriKit intents (generated from
        // Intents.intentdefinition) were removed in favour of modern App Intents.
        let handler: Any = {
            switch intent {
            case is INShareFocusStatusIntent:
                return FocusStatusIntentHandler()
            default:
                return self
            }
        }()
        Current.Log.info("for \(intent) found handler \(handler)")
        return handler
    }
}

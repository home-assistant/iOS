import Foundation
import Intents

public enum IntentHandlerFactory {
    public static func handler(for intent: INIntent) -> Any {
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

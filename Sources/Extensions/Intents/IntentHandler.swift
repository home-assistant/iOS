import Intents
import Shared

class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        RoutingIntentHandler.handler(for: intent)
    }
}

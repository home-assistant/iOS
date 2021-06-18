import Intents
import Shared

class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        let handler: Any = {
            if intent is FireEventIntent {
                return FireEventIntentHandler()
            }
            if intent is CallServiceIntent {
                return CallServiceIntentHandler()
            }
            if intent is SendLocationIntent {
                return SendLocationIntentHandler()
            }
            if intent is GetCameraImageIntent {
                return GetCameraImageIntentHandler()
            }
            if intent is RenderTemplateIntent {
                return RenderTemplateIntentHandler()
            }
            if intent is PerformActionIntent {
                return PerformActionIntentHandler()
            }
            if intent is UpdateSensorsIntent {
                return UpdateSensorsIntentHandler()
            }
            #if compiler(>=5.5)
            if #available(iOS 15, *), intent is INShareFocusStatusIntent {
                return FocusStatusIntentHandler()
            }
            #endif
            if #available(iOS 14, *), intent is WidgetActionsIntent {
                return WidgetActionsIntentHandler()
            }
            return self
        }()

        Current.Log.info("for \(intent) found handler \(handler)")
        return handler
    }
}

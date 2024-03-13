import Foundation
import Intents

public enum IntentHandlerFactory {
    public static func handler(for intent: INIntent) -> Any {
        let handler: Any = {
            switch intent {
            case is FireEventIntent:
                return FireEventIntentHandler()
            case is CallServiceIntent:
                return CallServiceIntentHandler()
            case is SendLocationIntent:
                return SendLocationIntentHandler()
            case is GetCameraImageIntent:
                return GetCameraImageIntentHandler()
            case is RenderTemplateIntent:
                return RenderTemplateIntentHandler()
            case is PerformActionIntent:
                return PerformActionIntentHandler()
            case is UpdateSensorsIntent:
                return UpdateSensorsIntentHandler()
            case is AssistIntent:
                return AssistIntentHandler()
            case is OpenPageIntent, is WidgetOpenPageIntent:
                return OpenPageIntentHandler()
            case is INShareFocusStatusIntent:
                return FocusStatusIntentHandler()
            case is WidgetActionsIntent:
                return WidgetActionsIntentHandler()
            case is AssistInAppIntent:
                return AssistInAppIntentHandler()
            default:
                return self
            }
        }()
        Current.Log.info("for \(intent) found handler \(handler)")
        return handler
    }
}

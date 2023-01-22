import Foundation
import Intents

@available(iOS 13, watchOS 6, *)
public enum IntentHandlerFactory {
    // swiftlint:disable:next cyclomatic_complexity
    public static func handler(for intent: INIntent) -> Any {
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
            if intent is AssistIntent {
                return AssistIntentHandler()
            }
            if intent is OpenPageIntent || intent is WidgetOpenPageIntent {
                return OpenPageIntentHandler()
            }
            if #available(iOS 15, watchOS 8, *), intent is INShareFocusStatusIntent {
                return FocusStatusIntentHandler()
            }
            if #available(iOS 14, watchOS 7, *), intent is WidgetActionsIntent {
                return WidgetActionsIntentHandler()
            }
            return self
        }()

        Current.Log.info("for \(intent) found handler \(handler)")
        return handler
    }
}

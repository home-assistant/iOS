import Foundation
import Intents
import PromiseKit

@available(iOS 15, watchOS 8, *)
class FocusStatusIntentHandler: NSObject, INShareFocusStatusIntentHandling {
    func handle(intent: INShareFocusStatusIntent, completion: @escaping (INShareFocusStatusIntentResponse) -> Void) {
        let currentState = intent.focusStatus
        Current.focusStatus.update(fromReceived: currentState)
        Current.Log.info("starting, status from intent is \(String(describing: currentState)) from \(intent)")

        let limitedTo: [SensorProvider.Type]?

        if Current.isCatalyst {
            limitedTo = [FocusSensor.self]
        } else {
            limitedTo = nil
        }

        when(fulfilled: Current.apis.map {
            $0.UpdateSensors(trigger: .Siri, limitedTo: limitedTo)
        }).done {
            Current.Log.info("finished successfully")
            completion(.init(code: .success, userActivity: nil))
        }.catch { error in
            Current.Log.error("failed: \(error)")
            completion(.init(code: .failure, userActivity: nil))
        }
    }
}

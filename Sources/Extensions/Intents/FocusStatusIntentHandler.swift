#if compiler(>=5.5) && !targetEnvironment(macCatalyst)
import Foundation
import Intents
import PromiseKit
import Shared

@available(iOS 15, *)
class FocusStatusIntentHandler: NSObject, INShareFocusStatusIntentHandling {
    func handle(intent: INShareFocusStatusIntent, completion: @escaping (INShareFocusStatusIntentResponse) -> Void) {
        let currentState = intent.focusStatus
        Current.focusStatus.update(fromReceived: currentState)
        Current.Log.info("starting, status from intent is \(String(describing: currentState)) from \(intent)")

        Current.api.then(on: nil) {
            $0.UpdateSensors(trigger: .Siri)
        }.done {
            Current.Log.info("finished successfully")
            completion(.init(code: .success, userActivity: nil))
        }.catch { error in
            Current.Log.error("failed: \(error)")
            completion(.init(code: .failure, userActivity: nil))
        }
    }
}
#endif

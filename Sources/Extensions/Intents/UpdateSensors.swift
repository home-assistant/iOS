import Foundation
import Shared
import PromiseKit

class UpdateSensorsIntentHandler: NSObject, UpdateSensorsIntentHandling {
    func handle(intent: UpdateSensorsIntent, completion: @escaping (UpdateSensorsIntentResponse) -> Void) {
        Current.Log.info("starting")

        Current.api.then {
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

import Foundation
import Intents
import PromiseKit

class FocusStatusIntentHandler: NSObject, INShareFocusStatusIntentHandling {
    /// How long to let a status change settle before reporting it.
    ///
    /// Switching Focus pushes "nothing is running" for the Focus that ended and runs the starting
    /// Focus' filter separately — the filter in the app, which iOS may have to launch first.
    /// Sending the moment the status arrives publishes that gap as a real state, so Home Assistant
    /// sees the Focus sensors blank mid-switch and stays that way if the filter's own update never
    /// lands. Waiting lets the filter run first, so one settled state goes out instead of two.
    static var settleDelay: TimeInterval = 5

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

        firstly {
            after(seconds: Self.settleDelay)
        }.then {
            when(fulfilled: Current.apis.map {
                $0.UpdateSensors(trigger: .Siri, limitedTo: limitedTo)
            })
        }.done {
            Current.Log.info("finished successfully")
            completion(.init(code: .success, userActivity: nil))
        }.catch { error in
            Current.Log.error("failed: \(error)")
            completion(.init(code: .failure, userActivity: nil))
        }
    }
}

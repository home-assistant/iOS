import Foundation
import Intents
import PromiseKit

class FocusStatusIntentHandler: NSObject, INShareFocusStatusIntentHandling {
    /// How long to let a status change settle before reporting it.
    ///
    /// Switching Focus pushes "not focused" for the Focus that ended and performs the starting
    /// Focus' filter separately, in the app, which iOS may have to launch first. Sending the moment
    /// the status arrives publishes that gap as a real state. Waiting lets the filter run first, so
    /// one settled state goes out instead of two.
    static var settleDelay: TimeInterval = 5

    func handle(intent: INShareFocusStatusIntent, completion: @escaping (INShareFocusStatusIntentResponse) -> Void) {
        // Read from the intent rather than from `INFocusStatusCenter`, as Apple's sample does: in
        // an extension the center answers "not focused" whatever is on.
        let pushedStatus = intent.focusStatus
        Current.focusStatus.record(pushed: pushedStatus)
        Current.Log.info("starting, status from intent is \(String(describing: pushedStatus)) from \(intent)")

        // `Current.apis` picks each server's URL from the cached network information, which this
        // extension — launched by iOS to hand us the status — doesn't have yet. Without it a server
        // only reachable on the home network has no usable URL, `apis` is empty, and the update
        // "succeeds" without reaching anyone. Fetched during the wait rather than after it.
        let networkRefreshed = Promise<Void> { seal in
            Task {
                await Current.connectivity.refreshNetworkInformation()
                seal.fulfill(())
            }
        }

        firstly {
            when(fulfilled: after(seconds: Self.settleDelay), networkRefreshed)
        }.then { _ -> Promise<Void> in
            let apis = Current.apis
            if apis.isEmpty {
                Current.Log.error("no server to report the focus status to")
            }
            // Only the Focus sensors: an Intents extension gets little time to begin with, and the
            // wait above spends some of it, so a full update risks being cut off before the state
            // this handler exists to report goes out.
            return when(fulfilled: apis.map {
                $0.updateFocusSensors(trigger: .Siri)
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

import CoreLocation
import Foundation
import Intents
import PromiseKit
import UIKit

@available(iOS 13, watchOS 6, *)
class SendLocationIntentHandler: NSObject, SendLocationIntentHandling {
    func resolveLocation(
        for intent: SendLocationIntent,
        with completion: @escaping (INPlacemarkResolutionResult) -> Void
    ) {
        if let loc = intent.location {
            Current.Log.info("using provided \(loc)")
            completion(.success(with: loc))
        } else {
            Current.Log.info("requesting a value")
            completion(.needsValue())
        }
    }

    func handle(intent: SendLocationIntent, completion: @escaping (SendLocationIntentResponse) -> Void) {
        Current.Log.verbose("Handling send location")

        when(fulfilled: Current.apis.map { api in
            api.SubmitLocation(updateType: .Siri, location: intent.location?.location, zone: nil)
        }).done { _ in
            Current.Log.verbose("Successfully submitted location")

            let resp = SendLocationIntentResponse(code: .success, userActivity: nil)
            resp.location = intent.location
            completion(resp)
        }.catch { error in
            Current.Log.error("Error sending location during Siri Shortcut call: \(error)")
            let resp = SendLocationIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Error sending location during Siri Shortcut call: \(error.localizedDescription)"
            completion(resp)
        }
    }
}

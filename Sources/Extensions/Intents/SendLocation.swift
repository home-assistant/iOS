//
//  SendLocation.swift
//  SiriIntents
//
//  Created by Robert Trencheny on 9/17/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import Shared
import Intents
import PromiseKit

class SendLocationIntentHandler: NSObject, SendLocationIntentHandling {
    func resolveLocation(for intent: SendLocationIntent,
                         with completion: @escaping (INPlacemarkResolutionResult) -> Void) {
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

        Current.api.then { api in
            api.SubmitLocation(updateType: .Siri, location: intent.location?.location, zone: nil)
        }.done { _ in
            Current.Log.verbose("Successfully submitted location")

            let resp = SendLocationIntentResponse(code: .success, userActivity: nil)
            resp.location = intent.location
            completion(resp)
            return
        }.catch { error in
            Current.Log.error("Error sending location during Siri Shortcut call: \(error)")
            let resp = SendLocationIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Error sending location during Siri Shortcut call: \(error.localizedDescription)"
            completion(resp)
            return
        }

    }

}

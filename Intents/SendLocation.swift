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
import MapKit
import Intents

class SendLocationIntentHandler: NSObject, SendLocationIntentHandling {
    func confirm(intent: SendLocationIntent, completion: @escaping (SendLocationIntentResponse) -> Void) {

        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            Current.Log.error("Can't get a authenticated API \(error)")
            completion(SendLocationIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        guard intent.location != nil else {
            let resp = SendLocationIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Location is not set"
            completion(resp)
            return
        }

        completion(SendLocationIntentResponse(code: .ready, userActivity: nil, place: intent.location))
    }

    func handle(intent: SendLocationIntent, completion: @escaping (SendLocationIntentResponse) -> Void) {
        Current.Log.verbose("Handling send location")

        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            Current.Log.error("Failed to get Home Assistant API during handle of sendLocation")
            completion(SendLocationIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        api.SubmitLocation(updateType: .Siri, location: intent.location?.location, zone: nil).done { _ in
            Current.Log.verbose("Successfully submitted location")

            completion(SendLocationIntentResponse(code: .success, userActivity: nil, place: intent.location))
            return
        }.catch { error in
            Current.Log.error("Error sending location during Siri Shortcut call: \(error)")
            let resp = SendLocationIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Error sending location during Siri Shortcut call: \(error.localizedDescription)"
            completion(resp)
            return
        }

    }

    func resolveLocation(for intent: SendLocationIntent,
                         with completion: @escaping (INPlacemarkResolutionResult) -> Void) {
        guard let place = intent.location else {
            completion(INPlacemarkResolutionResult.needsValue())
            return
        }

        completion(INPlacemarkResolutionResult.success(with: place))
    }
}

extension SendLocationIntentResponse {
    convenience init(code: SendLocationIntentResponseCode, userActivity: NSUserActivity?, place: CLPlacemark?) {
        self.init(code: code, userActivity: userActivity)
        Current.Log.verbose("Confirming send location as place \(place.debugDescription)")

        self.location = place

        return
    }
}

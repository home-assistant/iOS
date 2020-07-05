//
//  FireEvent.swift
//  Intents
//
//  Created by Robert Trencheny on 9/17/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Shared
import Intents

class FireEventIntentHandler: NSObject, FireEventIntentHandling {
    func resolveEventName(for intent: FireEventIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let eventName = intent.eventName {
            completion(.success(with: eventName))
            return
        }
        completion(.confirmationRequired(with: intent.eventName))
    }

    func resolveEventData(for intent: FireEventIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let eventData = intent.eventData {
            completion(.success(with: eventData))
            return
        }
        completion(.confirmationRequired(with: intent.eventData))
    }

    func confirm(intent: FireEventIntent, completion: @escaping (FireEventIntentResponse) -> Void) {
        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            Current.Log.error("Can't get a authenticated API \(error)")
            completion(FireEventIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        completion(FireEventIntentResponse(code: .ready, userActivity: nil))
    }

    // swiftlint:disable:next function_body_length
    func handle(intent: FireEventIntent, completion: @escaping (FireEventIntentResponse) -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            completion(FireEventIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        Current.Log.verbose("Handling fire event shortcut \(intent)")

        var eventDataDict: [String: Any] = [:]

        if let storedData = intent.eventData, storedData.isEmpty == false, let data = storedData.data(using: .utf8) {
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data,
                                                                    options: .allowFragments) as? [String: Any] {

                    var isGenericPayload: Bool = true

                    if let eventName = jsonArray["eventName"] as? String {
                        intent.eventName = eventName
                        isGenericPayload = false
                    }

                    if let innerEventData = jsonArray["eventData"] as? [String: Any] {
                        eventDataDict = innerEventData
                        isGenericPayload = false
                    }

                    if isGenericPayload {
                        Current.Log.verbose("No known keys found, assuming generic payload")
                        eventDataDict = jsonArray
                    }
                } else {
                    Current.Log.error("Unable to parse event data to JSON during shortcut: \(storedData)")
                    let resp = FireEventIntentResponse(code: .failure, userActivity: nil)
                    resp.error = "Unable to parse event data to JSON during shortcut"
                    completion(resp)
                    return
                }
            } catch let error as NSError {
                Current.Log.error("Error when parsing event data to JSON during FireEvent: \(error)")
                let resp = FireEventIntentResponse(code: .failure, userActivity: nil)
                resp.error = "Service data not dictionary or JSON"
                completion(resp)
                return
            }
        }

        api.CreateEvent(eventType: intent.eventName!, eventData: eventDataDict).done { _ in
            Current.Log.verbose("Successfully fired event during shortcut")
            let resp = FireEventIntentResponse(code: .success, userActivity: nil)
            resp.eventName = intent.eventName
            completion(resp)
        }.catch { error in
            Current.Log.error("Error when firing event in shortcut \(error)")
            let resp = FireEventIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Error when firing event in shortcut: \(error.localizedDescription)"
            completion(resp)
        }
    }
}

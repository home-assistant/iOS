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

class FireEventIntentHandler: NSObject, FireEventIntentHandling {
    func confirm(intent: FireEventIntent, completion: @escaping (FireEventIntentResponse) -> Void) {
        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            print("Can't get a authenticated API", error)
            completion(FireEventIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        if intent.eventName != nil && intent.eventData != nil {
            // Event name and data was already set
            completion(FireEventIntentResponse(code: .ready, userActivity: nil))
        } else if let pasteboardString = UIPasteboard.general.string {
            if intent.eventName != nil {
                // Only service name was set, get data from clipboard
                intent.eventData = pasteboardString
            } else {
                // Nothing was set, hope there's a JSON object on clipboard containing valid JSON
                // which we can use as event data.
                let data = pasteboardString.data(using: .utf8)!
                if JSONSerialization.isValidJSONObject(data) {
                    intent.eventData = String(data: data, encoding: .utf8)
                } else {
                    print("Error when parsing clipboard contents to JSON during FireEvent")
                    completion(FireEventIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
                }

            }
            completion(FireEventIntentResponse(code: .ready, userActivity: nil))
        } else {
            completion(FireEventIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
        }
    }
    func handle(intent: FireEventIntent, completion: @escaping (FireEventIntentResponse) -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            completion(FireEventIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        if let eventName = intent.eventName, let eventData = intent.eventData {
            print("Handling fire event shortcut", eventName, eventData)
            let data = eventData.data(using: .utf8)!
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data,
                                                                    options: .allowFragments) as? [String: Any] {
                    api.createEvent(eventType: eventName, eventData: jsonArray).done { _ in
                            print("Successfully fired event during shortcut")
                            completion(FireEventIntentResponse(code: .success, userActivity: nil))
                        }.catch { error in
                            print("Error when firing event in shortcut", error)
                            completion(FireEventIntentResponse(code: .failure, userActivity: nil))
                    }

                } else {
                    print("Unable to parse data to JSON during shortcut")
                    completion(FireEventIntentResponse(code: .failure, userActivity: nil))
                }
            } catch let error as NSError {
                print("Error when parsing service data to JSON during FireEvent", error)
                completion(FireEventIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
            }

        } else {
            print("Unable to unwrap intent.eventName and intent.eventData")
            completion(FireEventIntentResponse(code: .failure, userActivity: nil))
        }
    }
}

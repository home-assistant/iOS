//
//  CallService.swift
//  Intents
//
//  Created by Robert Trencheny on 9/17/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Shared

class CallServiceIntentHandler: NSObject, CallServiceIntentHandling {

    func confirm(intent: CallServiceIntent, completion: @escaping (CallServiceIntentResponse) -> Void) {
        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            print("Can't get a authenticated API", error)
            completion(CallServiceIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        if intent.serviceDomain != nil && intent.service != nil && intent.payload != nil {
            // Service name and data was already set
            completion(CallServiceIntentResponse(code: .ready, userActivity: nil))
        } else if let pasteboardString = UIPasteboard.general.string {
            if intent.service != nil {
                // Only service name was set, get data from clipboard
                intent.payload = pasteboardString
            } else {
                // Nothing was set, hope there's a JSON object on clipboard containing service name and data
                // JSON object should be same payload as we send to HA + a service key
                let data = pasteboardString.data(using: .utf8)!
                do {
                    if let jsonArray = try JSONSerialization.jsonObject(with: data,
                                                                        options: .allowFragments) as? [String: Any] {
                        if let jsonSN = jsonArray["serivceName"] as? String {
                            intent.service = jsonSN
                        }
                        if let data = jsonArray["data"] {
                            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
                            intent.payload = String(data: jsonData, encoding: .utf8)
                        }
                    } else {
                        print("Unable to parse pasteboard JSON")
                        completion(CallServiceIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
                    }
                } catch let error as NSError {
                    print("Error when parsing clipboard contents to JSON during CallService", error)
                    completion(CallServiceIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
                }

            }
            completion(CallServiceIntentResponse(code: .ready, userActivity: nil))
        } else {
            completion(CallServiceIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
        }
    }

    func handle(intent: CallServiceIntent, completion: @escaping (CallServiceIntentResponse) -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            completion(CallServiceIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        if let domain = intent.serviceDomain, let service = intent.service, let data = intent.payload {
            print("Handling call service shortcut", service, data)

            let data = data.data(using: .utf8)!
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data,
                                                                    options: .allowFragments) as? [String: Any] {

                    api.callService(domain: domain, service: service, serviceData: jsonArray,
                                    shouldLog: true).done { _ in
                        print("Successfully called service during shortcut")
                        completion(CallServiceIntentResponse(code: .success, userActivity: nil))
                    }.catch { error in
                        print("Error when calling service in shortcut", error)
                        completion(CallServiceIntentResponse(code: .failure, userActivity: nil))
                    }

                } else {
                    print("Unable to parse data to JSON during shortcut")
                    completion(CallServiceIntentResponse(code: .failure, userActivity: nil))
                }
            } catch let error as NSError {
                print("Error when parsing service data to JSON during CallService", error)
                completion(CallServiceIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
            }

        } else {
            print("Unable to unwrap intent.service and intent.data")
            completion(CallServiceIntentResponse(code: .failure, userActivity: nil))
        }
    }
}

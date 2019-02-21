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
import CleanroomLogger

class CallServiceIntentHandler: NSObject, CallServiceIntentHandling {

    func confirm(intent: CallServiceIntent, completion: @escaping (CallServiceIntentResponse) -> Void) {
        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            Log.error?.message("Can't get a authenticated API \(error)")
            completion(CallServiceIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        completion(CallServiceIntentResponse(code: .ready, userActivity: nil))
    }

    // swiftlint:disable:next function_body_length
    func handle(intent: CallServiceIntent, completion: @escaping (CallServiceIntentResponse) -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            completion(CallServiceIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        var successCode: CallServiceIntentResponseCode = .success

        var payloadDict: [String: Any] = [:]

        if intent.serviceDomain != nil && intent.service != nil {
            // Service name and data was already set
            Log.verbose?.message("Service name and data was already set")

            if let payload = intent.payload {
                let data = payload.data(using: .utf8)!
                do {
                    if let jsonArray = try JSONSerialization.jsonObject(with: data,
                                                                        options: .allowFragments) as? [String: Any] {
                        payloadDict = jsonArray
                    } else {
                        Log.error?.message("Unable to parse stored payload: \(payload)")
                        completion(.failure(error: "Unable to parse stored payload"))
                        return
                    }
                } catch let error as NSError {
                    Log.error?.message("Error when parsing stored payload to JSON during CallService \(error)")
                    let errStr = "Error when parsing stored payload to JSON during CallService: \(error)"
                    completion(.failure(error: errStr))
                    return
                }
            }
        } else if let pasteboardString = UIPasteboard.general.string {
            Log.verbose?.message("Intent is not configured, expecting all values on pasteboard")

            // Nothing was set, hope there's a JSON object on clipboard containing service name and data.
            // Alternatively, it could just be the payload to send if we don't find the keys that define a generic data.
            // JSON object should be same payload as we send to HA + a service key
            Log.verbose?.message("Nothing was set, hope there's JSON on clipboard containing service name and data")
            let data = pasteboardString.data(using: .utf8)!
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data,
                                                                    options: .allowFragments) as? [String: Any] {
                    var isGenericPayload: Bool = true
                    Log.verbose?.message("Got JSON dictionary \(jsonArray)")
                    if let serviceToSplit = jsonArray["service"] as? String {
                        let split = serviceToSplit.components(separatedBy: ".")
                        intent.serviceDomain = split[0]
                        intent.service = split[1]
                        isGenericPayload = false
                    }
                    if let data = jsonArray["serviceData"] as? [String: Any] {
                        payloadDict = data
                        isGenericPayload = false
                    }
                    // We didn't find any of the above keys in the payload, let's assume this is a generic payload
                    // and use the decoded data as the payload.
                    if isGenericPayload {
                        Log.verbose?.message("No known keys found, assuming generic payload")
                        payloadDict = jsonArray
                    }

                    successCode = .successViaClipboard
                } else {
                    Log.error?.message("Unable to parse pasteboard JSON: \(pasteboardString)")
                    completion(CallServiceIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
                    return
                }
            } catch let error as NSError {
                Log.error?.message("Error when parsing clipboard contents to JSON during CallService: \(error)")
                completion(CallServiceIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
                return
            }
        }

        Log.verbose?.message("Configured intent \(intent)")

        if let domain = intent.serviceDomain, let service = intent.service {
            Log.verbose?.message("Handling call service shortcut \(domain), \(service)")

            api.callService(domain: domain, service: service, serviceData: payloadDict, shouldLog: true).done { _ in
                Log.verbose?.message("Successfully called service during shortcut")
                completion(CallServiceIntentResponse(code: successCode, userActivity: nil))
            }.catch { error in
                Log.error?.message("Error when calling service in shortcut \(error)")
                let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
                resp.error = "Error during api.callService: \(error.localizedDescription)"
                completion(resp)
            }

        } else {
            Log.warning?.message("Unable to unwrap intent.serviceDomain and intent.serviceName \(intent)")
            let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Unable to unwrap intent.serviceDomain and intent.serviceName"
            completion(resp)
        }
    }
}

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
import Intents

class CallServiceIntentHandler: NSObject, CallServiceIntentHandling {
    func resolveService(for intent: CallServiceIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        guard let serviceName = intent.service else {
            completion(.confirmationRequired(with: intent.service))
            return
        }

        completion(.success(with: serviceName))
        return
    }

    func resolvePayload(for intent: CallServiceIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        guard let servicePayload = intent.payload else {
            completion(.confirmationRequired(with: intent.payload))
            return
        }

        completion(.success(with: servicePayload))
        return
    }

    func provideServiceOptions(for intent: CallServiceIntent, with completion: @escaping ([String]?, Error?) -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            completion(nil, HomeAssistantAPI.APIError.managerNotAvailable)
            return
        }

        api.GetServices().done { serviceResp in
            var allServices: [String] = []

            for domainContainer in serviceResp.sorted(by: { (a, b) -> Bool in
                return a.Domain < b.Domain
            }) {
                for service in domainContainer.Services.sorted(by: { (a, b) -> Bool in
                    return a.key < b.key
                }) {
                    allServices.append("\(domainContainer.Domain).\(service.key)")
                }
            }
            completion(allServices, nil)
        }.catch { error in
            completion(nil, error)
        }
    }

    func confirm(intent: CallServiceIntent, completion: @escaping (CallServiceIntentResponse) -> Void) {
        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            Current.Log.error("Can't get a authenticated API \(error)")
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

        var payloadDict: [String: Any] = [:]

        if let payload = intent.payload {
            let data = payload.data(using: .utf8)!
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data,
                                                                    options: .allowFragments) as? [String: Any] {
                    payloadDict = jsonArray
                } else {
                    Current.Log.error("Unable to parse stored payload: \(payload)")
                    completion(.failure(error: "Unable to parse stored payload"))
                    return
                }
            } catch let error as NSError {
                Current.Log.error("Error when parsing stored payload to JSON during CallService \(error)")
                let errStr = "Error when parsing stored payload to JSON during CallService: \(error)"
                completion(.failure(error: errStr))
                return
            }
        }

        Current.Log.verbose("Configured intent \(intent)")

        guard let serviceName = intent.service else {
            completion(.failure(error: "No service name provided"))
            return
        }

        let splitServiceNameInput = serviceName.split(separator: ".")

        guard splitServiceNameInput.count == 2 else {
            Current.Log.warning("Invalid service \(serviceName), count is \(splitServiceNameInput.count)")
            let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Invalid service name"
            completion(resp)
            return
        }

        let domain = String(splitServiceNameInput[0])
        let service = String(splitServiceNameInput[1])

        Current.Log.verbose("Handling call service shortcut \(domain), \(service)")

        api.CallService(domain: domain, service: service, serviceData: payloadDict, shouldLog: true).done { _ in
            Current.Log.verbose("Successfully called service during shortcut")
            let resp = CallServiceIntentResponse(code: .success, userActivity: nil)
            resp.domain = domain
            resp.service = service
            completion(resp)
            return
        }.catch { error in
            Current.Log.error("Error when calling service in shortcut \(error)")
            let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Error during api.callService: \(error.localizedDescription)"
            completion(resp)
        }
    }
}

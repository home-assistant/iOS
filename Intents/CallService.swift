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
import PromiseKit

class CallServiceIntentHandler: NSObject, CallServiceIntentHandling {
    func confirm(intent: CallServiceIntent, completion: @escaping (CallServiceIntentResponse) -> Void) {
        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            Current.Log.error("Can't get a authenticated API \(error)")
            let resp = CallServiceIntentResponse(code: .failureConnectivity, userActivity: nil)
            resp.service = intent.service
            resp.error = "Can't get a authenticated API \(error)"
            completion(resp)
            return
        }

        if let payload = intent.payload {
            if let data = payload.data(using: .utf8) {
                do {
                    _ = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
                } catch {
                    Current.Log.error("Unable to parse JSON string to dictionary: \(payload)")
                    let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
                    resp.service = intent.service
                    resp.error = "Unable to parse JSON string to dictionary"
                    completion(resp)
                    return
                }
            } else {
                Current.Log.error("Unable to convert String to Data, check JSON syntax")
                let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
                resp.service = intent.service
                resp.error = "Unable to convert String to Data, check JSON syntax"
                completion(resp)
                return
            }
        }

        let resp = CallServiceIntentResponse(code: .ready, userActivity: nil)
        resp.service = intent.service
        completion(resp)
    }

    // swiftlint:disable:next function_body_length
    func handle(intent: CallServiceIntent, completion: @escaping (CallServiceIntentResponse) -> Void) {
        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            Current.Log.error("Can't get a authenticated API \(error)")
            let resp = CallServiceIntentResponse(code: .failureConnectivity, userActivity: nil)
            resp.service = intent.service
            resp.error = "Can't get a authenticated API \(error)"
            completion(resp)
            return
        }
        var payloadDict: [String: Any] = [:]

        if let payload = intent.payload {
            if let data = payload.data(using: .utf8) {
                do {
                    if let jsonArray = try JSONSerialization.jsonObject(with: data,
                                                                        options: .allowFragments) as? [String: Any] {
                        payloadDict = jsonArray
                    } else {
                        Current.Log.error("Unable to parse JSON string to dictionary: \(payload)")
                        let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
                        resp.service = intent.service
                        resp.error = "Unable to parse JSON string to dictionary"
                        completion(resp)
                        return
                    }
                } catch let error as NSError {
                    Current.Log.error("Error when parsing payload to JSON \(error)")
                    let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
                    resp.service = intent.service
                    resp.error = "Error when parsing payload to JSON: \(error)"
                    completion(resp)
                    return
                }
            } else {
                Current.Log.error("Unable to convert String to Data, check JSON syntax")
                let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
                resp.service = intent.service
                resp.error = "Unable to convert String to Data, check JSON syntax"
                completion(resp)
                return
            }
        }

        Current.Log.verbose("Configured intent \(intent)")

        if let id = intent.service?.identifier {
            let splitID = id.components(separatedBy: ".")
            let domain = splitID[0]
            let service = splitID[1]
            Current.Log.verbose("Handling call service shortcut \(domain), \(service)")

            firstly {
                HomeAssistantAPI.authenticatedAPIPromise
            }.then { api in
                api.CallService(domain: domain, service: service, serviceData: payloadDict, shouldLog: true)
            }.done { _ in
                Current.Log.verbose("Successfully called service during shortcut")
                let resp = CallServiceIntentResponse(code: .success, userActivity: nil)
                resp.service = intent.service
                completion(resp)
            }.catch { error in
                Current.Log.error("Error when calling service in shortcut \(error)")
                let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
                resp.error = "Error during api.callService: \(error)"
                resp.service = intent.service
                completion(resp)
            }
        } else {
            Current.Log.warning("Unable to unwrap service \(intent)")
            let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Unable to unwrap service parameter"
            resp.service = intent.service
            completion(resp)
        }
    }

    func resolveService(for intent: CallServiceIntent, with completion: @escaping (ServiceResolutionResult) -> Void) {
        guard let service = intent.service else {
            completion(ServiceResolutionResult.needsValue())
            return
        }
        completion(ServiceResolutionResult.success(with: service))
        return
    }

    func provideServiceOptions(for intent: CallServiceIntent, with completion: @escaping ([Service]?, Error?) -> Void) {

        firstly {
            HomeAssistantAPI.authenticatedAPIPromise
        }.then { api in
            api.GetServices()
        }.map { servicesResp -> [Service] in
            var allServices: [Service] = []

            for aDomain in servicesResp {
                for aService in aDomain.Services {
                    let id = aDomain.Domain + "." + aService.key
                    let service = Service(identifier: id, display: id)
                    service.serviceDescription = aService.value.Description
                    allServices.append(service)
                }
            }

            return allServices.sorted { $0.identifier! < $1.identifier! }
        }.done { services in
            completion(services, nil)
        }.catch { err in
            completion(nil, err)
        }
    }

    func resolvePayload(for intent: CallServiceIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let payload = intent.payload {
            completion(INStringResolutionResult.success(with: payload))
            return
        }

        completion(INStringResolutionResult.notRequired())
    }
}

//
//  GetCameraImage.swift
//  SiriIntents
//
//  Created by Robert Trencheny on 2/19/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Shared

class GetCameraImageIntentHandler: NSObject, GetCameraImageIntentHandling {

    func confirm(intent: GetCameraImageIntent, completion: @escaping (GetCameraImageIntentResponse) -> Void) {
        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            print("Can't get a authenticated API", error)
            completion(GetCameraImageIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        if intent.serviceDomain != nil && intent.service != nil && intent.payload != nil {
            // Service name and data was already set
            completion(GetCameraImageIntentResponse(code: .ready, userActivity: nil))
        } else if let pasteboardString = UIPasteboard.general.string {
            if intent.service != nil {
                // Only service name was set, get data from clipboard
                intent.payload = pasteboardString
            }
            completion(GetCameraImageIntentResponse(code: .ready, userActivity: nil))
        } else {
            completion(GetCameraImageIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
        }
    }

    func handle(intent: GetCameraImageIntent, completion: @escaping (GetCameraImageIntentResponse) -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            completion(GetCameraImageIntentResponse(code: .failureConnectivity, userActivity: nil))
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
                            let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
                            resp.error = "Error during api.callService: \(error.localizedDescription)"
                            completion(resp)
                    }

                } else {
                    print("Unable to parse data to JSON during shortcut")
                    let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
                    resp.error = "Unable to parse data to JSON"
                    completion(resp)
                }
            } catch let error as NSError {
                print("Error when parsing service data to JSON during CallService", error)
                completion(CallServiceIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
            }

        } else {
            print("Unable to unwrap intent.service and intent.data")
            let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Unable to unwrap intent.service and intent.data"
            completion(resp)
        }
    }
}

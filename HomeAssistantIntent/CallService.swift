//
//  CallService.swift
//  HomeAssistantIntent
//
//  Created by Robert Trencheny on 8/2/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import Shared

class CallServiceIntentHandler: NSObject, CallServiceIntentHandling {

    func confirm(intent: CallServiceIntent, completion: @escaping (CallServiceIntentResponse) -> Void) {
        print("Confirming call service", intent.serviceName, intent.serviceData)
        completion(CallServiceIntentResponse(code: .success, userActivity: nil))
    }

    func handle(intent: CallServiceIntent, completion: @escaping (CallServiceIntentResponse) -> Void) {
        print("Handling call service", intent.serviceName, intent.serviceData)
        completion(CallServiceIntentResponse(code: .success, userActivity: nil))
    }
}

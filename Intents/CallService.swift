//
//  CallService.swift
//  Intents
//
//  Created by Robert Trencheny on 9/17/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation

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

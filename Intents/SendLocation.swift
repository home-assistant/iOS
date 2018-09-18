//
//  SendLocation.swift
//  SiriIntents
//
//  Created by Robert Trencheny on 9/17/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation

class SendLocationIntentHandler: NSObject, SendLocationIntentHandling {
    func confirm(intent: SendLocationIntent, completion: @escaping (SendLocationIntentResponse) -> Void) {
        print("Confirming send location")

        completion(SendLocationIntentResponse(code: .ready, userActivity: nil))
    }

    func handle(intent: SendLocationIntent, completion: @escaping (SendLocationIntentResponse) -> Void) {
        print("Handling send location")
        completion(SendLocationIntentResponse(code: .success, userActivity: nil))
    }
}

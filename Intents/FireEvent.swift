//
//  FireEvent.swift
//  Intents
//
//  Created by Robert Trencheny on 9/17/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation

class FireEventIntentHandler: NSObject, FireEventIntentHandling {
    func confirm(intent: FireEventIntent, completion: @escaping (FireEventIntentResponse) -> Void) {
        print("Confirming fire event", intent.eventName, intent.eventData)
        completion(FireEventIntentResponse(code: .success, userActivity: nil))
    }
    func handle(intent: FireEventIntent, completion: @escaping (FireEventIntentResponse) -> Void) {
        print("Handling fire event", intent.eventName, intent.eventData)
        completion(FireEventIntentResponse(code: .success, userActivity: nil))
    }
}

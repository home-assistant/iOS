//
//  FireEvent.swift
//  HomeAssistantIntent
//
//  Created by Robert Trencheny on 8/2/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import Shared

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

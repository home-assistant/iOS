//
//  IntentHandler.swift
//  HomeAssistantIntent
//
//  Created by Robert Trencheny on 8/2/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Intents

class IntentHandler: INExtension {

    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.

        if intent is CallServiceIntent {
            return CallServiceIntentHandler()
        }

        if intent is SendLocationIntent {
            return SendLocationIntentHandler()
        }

        return self
    }

}

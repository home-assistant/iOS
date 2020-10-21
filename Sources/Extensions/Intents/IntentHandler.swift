//
//  IntentHandler.swift
//  Intents
//
//  Created by Robert Trencheny on 9/17/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Intents
import Shared

class IntentHandler: INExtension {
    private let updateTokenQueue: DispatchQueue = .init(label: "update-token")

    override func handler(for intent: INIntent) -> Any {
        // multiple intent handlers can be invoked at once. we want to make sure this is up-to-date, but
        // it causes double-frees if it's mutating the non-atomic property in concurrently.
        updateTokenQueue.sync {
            if let tokenInfo = Current.settingsStore.tokenInfo {
                Current.tokenManager = TokenManager(tokenInfo: tokenInfo)
            }
        }

        let handler: Any = {
            if intent is FireEventIntent {
                return FireEventIntentHandler()
            }
            if intent is CallServiceIntent {
                return CallServiceIntentHandler()
            }
            if intent is SendLocationIntent {
                return SendLocationIntentHandler()
            }
            if intent is GetCameraImageIntent {
                return GetCameraImageIntentHandler()
            }
            if intent is RenderTemplateIntent {
                return RenderTemplateIntentHandler()
            }
            if intent is PerformActionIntent {
                return PerformActionIntentHandler()
            }
            if intent is UpdateSensorsIntent {
                return UpdateSensorsIntentHandler()
            }
            if #available(iOS 14, *), intent is WidgetActionsIntent {
                return WidgetActionsIntentHandler()
            }
            return self
        }()

        Current.Log.info("for \(intent) found handler \(handler)")
        return handler
    }

}

//
//  HomeAssistantAPI+Notifications.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 9/16/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import DeviceKit
import Foundation
import PromiseKit
import Shared
import UserNotifications

extension HomeAssistantAPI {
    func handlePushAction(
        identifier: String,
        category: String?,
        userInfo: [AnyHashable: Any],
        userInput: String?
    ) -> Promise<Void> {
        return Promise { seal in
            guard let api = HomeAssistantAPI.authenticatedAPI() else {
                throw APIError.notConfigured
            }

            let action = Self.notificationActionEvent(
                identifier: identifier,
                category: category,
                actionData: userInfo["homeassistant"],
                textInput: userInput
            )

            Current.Log.verbose("Sending action: \(action.eventType) payload: \(action.eventData)")

            api.CreateEvent(eventType: action.eventType, eventData: action.eventData).done { _ -> Void in
                seal.fulfill(())
            }.catch {error in
                seal.reject(error)
            }
        }
    }

}

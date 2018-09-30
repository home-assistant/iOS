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

    func handlePushAction(identifier: String, userInfo: [AnyHashable: Any], userInput: String?) -> Promise<Bool> {
        return Promise { seal in
            guard let api = HomeAssistantAPI.authenticatedAPI() else {
                throw APIError.notConfigured
            }

            let device = Device()
            var eventData: [String: Any] = ["actionName": identifier,
                                            "sourceDevicePermanentID": Current.deviceIDProvider(),
                                            "sourceDeviceName": device.name,
                                            "sourceDeviceID": Current.settingsStore.deviceID]
            if let dataDict = userInfo["homeassistant"] {
                eventData["action_data"] = dataDict
            }
            if let textInput = userInput {
                eventData["response_info"] = textInput
                eventData["textInput"] = textInput
            }

            let eventType = "ios.notification_action_fired"
            api.createEvent(eventType: eventType, eventData: eventData).done { _ -> Void in
                seal.fulfill(true)
                }.catch {error in
                    seal.reject(error)
            }
        }
    }

}

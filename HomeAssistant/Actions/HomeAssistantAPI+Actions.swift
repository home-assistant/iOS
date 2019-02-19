//
//  HomeAssistantAPI+Actions.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 2/14/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import DeviceKit
import PromiseKit
import Shared

extension HomeAssistantAPI {

    func handleAction(actionID: String, actionName: String, source: ActionSource) -> Promise<Bool> {
        return Promise { seal in
            guard let api = HomeAssistantAPI.authenticatedAPI() else {
                throw APIError.notConfigured
            }

            let device = Device()
            let eventData: [String: Any] = ["actionName": actionName,
                                            "actionID": actionID,
                                            "triggerSource": source.description,
                                            "sourceDevicePermanentID": Constants.PermanentID,
                                            "sourceDeviceName": device.name,
                                            "sourceDeviceID": Current.settingsStore.deviceID]

            print("Sending action payload", eventData)

            let eventType = "ios.action_fired"
            api.createEvent(eventType: eventType, eventData: eventData).done { _ -> Void in
                seal.fulfill(true)
            }.catch {error in
                seal.reject(error)
            }
        }
    }

}

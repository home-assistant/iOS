//
//  PushRegistrationRequest.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 10/11/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class PushRegistrationRequest: Mappable {
    var AppBuildNumber: Int?
    var AppBundleIdentifer: String?
    var AppVersionNumber: String?
    var DeviceID: String?
    var DeviceLocalizedModel: String?
    var DeviceModel: String?
    var DeviceName: String?
    var DevicePermanentID: String?
    var DeviceSystemName: String?
    var DeviceSystemVersion: String?
    var DeviceType: String?
    var DeviceTimezone: String?
    var PushSounds: [String]?
    var PushToken: String?
    var UserEmail: String?
    var HomeAssistantVersion: String?
    var HomeAssistantTimezone: String?

    var APNSSandbox: Bool = false

    init() {}

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        AppBuildNumber         <- map["appBuildNumber"]
        AppBundleIdentifer     <- map["appBundleIdentifer"]
        AppVersionNumber       <- map["appVersionNumber"]
        DeviceID               <- map["deviceId"]
        DeviceName             <- map["deviceName"]
        DevicePermanentID      <- map["devicePermanentID"]
        DeviceSystemName       <- map["deviceSystemName"]
        DeviceSystemVersion    <- map["deviceSystemVersion"]
        DeviceType             <- map["deviceType"]
        DeviceTimezone         <- map["deviceTimezone"]
        PushSounds             <- map["pushSounds"]
        PushToken              <- map["pushToken"]
        UserEmail              <- map["userEmail"]
        APNSSandbox            <- map["apnsSandbox"]
        HomeAssistantVersion   <- map["homeAssistantVersion"]
        HomeAssistantTimezone  <- map["homeAssistantTimezone"]
    }
}

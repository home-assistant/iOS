//
//  IdentifyRequest.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 9/7/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class IdentifyRequest: Mappable {
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
    var Permissions: [String]?
    var PushID: String?
    var PushToken: String = "This space intentionally left blank"
    var PushSounds: [String]?
    var BatteryLevel: Int?
    var BatteryState: String?

    init() {}

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        AppBuildNumber         <- map["app.buildNumber"]
        AppBundleIdentifer     <- map["app.bundleIdentifer"]
        AppVersionNumber       <- map["app.versionNumber"]
        DeviceID               <- map["deviceId"]
        DeviceLocalizedModel   <- map["device.localizedModel"]
        DeviceModel            <- map["device.model"]
        DeviceName             <- map["device.name"]
        DevicePermanentID      <- map["device.permanentID"]
        DeviceSystemName       <- map["device.systemName"]
        DeviceSystemVersion    <- map["device.systemVersion"]
        DeviceType             <- map["device.type"]
        Permissions            <- map["permissions"]
        PushID                 <- map["pushId"]
        PushToken              <- map["pushToken"]
        PushSounds             <- map["pushSounds"]
        BatteryLevel           <- map["battery.level"]
        BatteryState           <- map["battery.state"]
    }
}

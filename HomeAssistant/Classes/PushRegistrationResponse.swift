//
//  PushRegistrationRequest.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 10/11/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class PushRegistrationResponse: Mappable {
    var APNSSandbox: Bool?
    var AppBuildNumber: Int?
    var AppBundleIdentifer: String?
    var AppVersionNumber: String?
    var DeviceId: String?
    var DeviceName: String?
    var DevicePermanentID: String?
    var DeviceSystemName: String?
    var DeviceSystemVersion: String?
    var DeviceTimezone: String?
    var DeviceType: String?
    var EndpointARN: String?
    var HomeAssistantTimezone: String?
    var HomeAssistantVersion: String?
    var IPAddress: String?
    var PushId: String?
    var PushSounds: [String]?
    var PushToken: String?
    var RegisteredAt: Date?
    var SNSPlatform: String?
    var SubscriptionARN: String?
    var UserEmail: String?

    init() {}

    required init?(map: Map) {

    }

    func mapping(map: Map) {
        APNSSandbox              <- map["registration.apnsSandbox"]
        AppBuildNumber           <- map["registration.appBuildNumber"]
        AppBundleIdentifer       <- map["registration.appBundleIdentifer"]
        AppVersionNumber         <- map["registration.appVersionNumber"]
        DeviceId                 <- map["registration.deviceId"]
        DeviceName               <- map["registration.deviceName"]
        DevicePermanentID        <- map["registration.devicePermanentID"]
        DeviceSystemName         <- map["registration.deviceSystemName"]
        DeviceSystemVersion      <- map["registration.deviceSystemVersion"]
        DeviceTimezone           <- map["registration.deviceTimezone"]
        DeviceType               <- map["registration.deviceType"]
        EndpointARN              <- map["registration.EndpointArn"]
        HomeAssistantTimezone    <- map["registration.homeAssistantTimezone"]
        HomeAssistantVersion     <- map["registration.homeAssistantVersion"]
        IPAddress                <- map["registration.ipAddress"]
        PushId                   <- map["registration.pushId"]
        PushSounds               <- map["registration.pushSounds"]
        PushToken                <- map["registration.pushToken"]
        RegisteredAt             <- map["registration.registeredAt"]
        SNSPlatform              <- map["registration.snsPlatform"]
        SubscriptionARN          <- map["registration.SubscriptionArn"]
        UserEmail                <- map["registration.userEmail"]
    }
}

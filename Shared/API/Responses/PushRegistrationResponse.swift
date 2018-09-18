//
//  PushRegistrationRequest.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 10/11/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

public class PushRegistrationResponse: Mappable {
    public var APNSSandbox: Bool?
    public var AppBuildNumber: Int?
    public var AppBundleIdentifer: String?
    public var AppVersionNumber: String?
    public var DeviceId: String?
    public var DeviceName: String?
    public var DevicePermanentID: String?
    public var DeviceSystemName: String?
    public var DeviceSystemVersion: String?
    public var DeviceTimezone: String?
    public var DeviceType: String?
    public var EndpointARN: String?
    public var HomeAssistantTimezone: String?
    public var HomeAssistantVersion: String?
    public var IPAddress: String?
    public var PushId: String?
    public var PushSounds: [String]?
    public var PushToken: String?
    public var RegisteredAt: Date?
    public var SNSPlatform: String?
    public var SubscriptionARN: String?
    public var UserEmail: String?

    init() {}

    required public init?(map: Map) {
    }

    public func mapping(map: Map) {
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

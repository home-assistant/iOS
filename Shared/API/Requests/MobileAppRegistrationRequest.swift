//
//  MobileAppRegistrationRequest.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 9/7/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class MobileAppRegistrationRequest: Mappable {
    var AppIdentifier: String?
    var AppVersion: String?
    var DeviceID: String?
    var DeviceName: String?
    var SupportsEncryption: Bool = true

    init() {}

    required init?(map: Map) {}

    func mapping(map: Map) {
        AppIdentifier         <- map["app_id"]
        AppVersion            <- map["app_version"]
        DeviceID              <- map["device_id"]
        DeviceName            <- map["device_name"]
        SupportsEncryption    <- map["supports_encryption"]
    }
}

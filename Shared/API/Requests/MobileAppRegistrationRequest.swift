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
    var AppData: [String: Any]?
    var AppIdentifier: String?
    var AppName: String?
    var AppVersion: String?
    var DeviceName: String?
    var Manufacturer: String?
    var Model: String?
    var OSName: String?
    var OSVersion: String?
    var SupportsEncryption: Bool = true

    init() {}

    required init?(map: Map) {}

    func mapping(map: Map) {
        AppData             <- map["app_data"]
        AppIdentifier       <- map["app_id"]
        AppName             <- map["app_name"]
        AppVersion          <- map["app_version"]
        DeviceName          <- map["device_name"]
        Manufacturer        <- map["manufacturer"]
        Model               <- map["model"]
        OSName              <- map["os_name"]
        OSVersion           <- map["os_version"]
        SupportsEncryption  <- map["supports_encryption"]
    }
}

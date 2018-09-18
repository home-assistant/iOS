//
//  Config.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

public class ConfigResponse: Mappable {
    public var Components: [String]?
    public var Version: String?
    public var ConfigDirectory: String?

    public var TemperatureUnit: String?
    public var LengthUnit: String?
    public var MassUnit: String?
    public var VolumeUnit: String?

    public var LocationName: String?
    public var Timezone: String?
    public var Latitude: Float?
    public var Longitude: Float?

    required public init?(map: Map) {}

    public func mapping(map: Map) {
        Components      <- map["components"]
        Version         <- map["version"]
        ConfigDirectory <- map["config_dir"]

        TemperatureUnit <- map["unit_system.temperature"]
        LengthUnit      <- map["unit_system.length"]
        MassUnit        <- map["unit_system.mass"]
        VolumeUnit      <- map["unit_system.volume"]

        LocationName    <- map["location_name"]
        Timezone        <- map["time_zone"]
        Latitude        <- map["latitude"]
        Longitude       <- map["longitude"]
    }
}

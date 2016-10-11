//
//  Config.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class ConfigResponse: Mappable {
    var Components: [String]?
    var Version: String?
    var ConfigDirectory: String?
    
    var TemperatureUnit: String?
    var LengthUnit: String?
    var MassUnit: String?
    var VolumeUnit: String?
    
    var LocationName: String?
    var Timezone: String?
    var Latitude: Float?
    var Longitude: Float?
    
    required init?(map: Map){
        
    }
    
    func mapping(map: Map) {
        Components      <- map["components"]
        Version         <- map["version"]
        ConfigDirectory <- map["config_dir"]
        
        TemperatureUnit <- map["unit_system.temperature"]
        LengthUnit      <- map["unit_system.length"]
        MassUnit        <- map["unit_system.mass"]
        VolumeUnit      <- map["unit_system.volume"]
        
        LocationName    <- map["location_name"]
        Timezone        <- map["timezone"]
        Latitude        <- map["latitude"]
        Longitude       <- map["longitude"]
    }
}

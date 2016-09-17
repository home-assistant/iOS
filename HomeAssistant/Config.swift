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
    
    var TemperatureUnit: String?
    
    var LocationName: String?
    var Timezone: String?
    var Latitude: Float?
    var Longitude: Float?
    
    required init?(map: Map){
        
    }
    
    func mapping(map: Map) {
        Components      <- map["components"]
        Version         <- map["version"]
        
        TemperatureUnit <- map["temperature_unit"]
        
        LocationName    <- map["location_name"]
        Timezone        <- map["timezone"]
        Latitude        <- map["latitude"]
        Longitude       <- map["longitude"]
    }
}

//
//  ZoneComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/10/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Zone: Entity {
    
    var Latitude: Double?
    var Longitude: Double?
    var Radius: Int?
    
    required init?(_ map: Map) {
        super.init(map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        Latitude  <- map["attributes.latitude"]
        Longitude <- map["attributes.longitude"]
        Radius    <- map["attributes.radius"]
    }
}
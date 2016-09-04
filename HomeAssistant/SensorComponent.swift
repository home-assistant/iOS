//
//  SensorComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Sensor: Entity {
    
    dynamic var UnitOfMeasurement: String? = nil
    dynamic var SensorClass: String? = nil

    override func mapping(map: Map) {
        super.mapping(map)
        
        UnitOfMeasurement <- map["attributes.unit_of_measurement"]
        SensorClass       <- map["attributes.sensor_class"]
    }
    
    override var ComponentIcon: String {
        return "mdi:eye"
    }
    
    override func StateIcon() -> String {
        if self.MobileIcon != nil { return self.MobileIcon! }
        if self.Icon != nil { return self.Icon! }
        
        if (self.UnitOfMeasurement == "°C" || self.UnitOfMeasurement == "°F") {
            return "mdi:thermometer"
        } else if (self.UnitOfMeasurement == "Mice") {
            return "mdi:mouse-variant"
        }
        return ComponentIcon
    }
}
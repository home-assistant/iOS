//
//  BinarySensorComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class BinarySensor: SwitchableEntity {
    
    var SensorClass: String?
    
    required init?(_ map: Map) {
        super.init(map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        SensorClass  <- map["attributes.sensor_class"]
    }
    
    override var ComponentIcon: String {
        return "mdi:radiobox-blank"
    }
    
    override func StateIcon() -> String {
        if self.MobileIcon != nil { return self.MobileIcon! }
        if self.Icon != nil { return self.Icon! }
        
        let activated = (self.IsOn == false)
        if self.SensorClass == nil && activated {
            return "mdi:checkbox-marked-circle"
        }
        switch (self.SensorClass!) {
            case "opening":
                return activated ? "mdi:crop-square" : "mdi:exit-to-app"
            case "moisture":
                return activated ? "mdi:water-off" : "mdi:water"
            case "light":
                return activated ? "mdi:brightness-5" : "mdi:brightness-7"
            case "sound":
                return activated ? "mdi:music-note-off" : "mdi:music-note"
            case "vibration":
                return activated ? "mdi:crop-portrait" : "mdi:vibrate"
            case "connectivity":
                return activated ? "mdi:server-network-off" : "mdi:server-network"
            case "safety", "gas", "smoke", "power":
                return activated ? "mdi:verified" : "mdi:alert"
            case "motion":
                return activated ? "mdi:walk" : "mdi:run"
            default:
                return activated ? "mdi:radiobox-blank" : "mdi:checkbox-marked-circle"
        }
    }
}
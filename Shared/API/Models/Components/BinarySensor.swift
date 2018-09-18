//
//  BinarySensorComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class BinarySensor: Entity {

    @objc dynamic var SensorClass: String?
    @objc dynamic var IsOn: Bool = false

    override func mapping(map: Map) {
        super.mapping(map: map)

        SensorClass  <- map["attributes.sensor_class"]
        IsOn         <- (map["state"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
    }

    override var ComponentIcon: String {
        return "mdi:radiobox-blank"
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func StateIcon() -> String {
        if self.MobileIcon != nil { return self.MobileIcon! }
        if self.Icon != nil { return self.Icon! }

        let activated = (self.IsOn == false)
        if let sensorClass = self.SensorClass {
            switch sensorClass {
            case "connectivity":
                return activated ? "mdi:server-network-off" : "mdi:server-network"
            case "light":
                return activated ? "mdi:brightness-5" : "mdi:brightness-7"
            case "moisture":
                return activated ? "mdi:water-off" : "mdi:water"
            case "motion":
                return activated ? "mdi:walk" : "mdi:run"
            case "occupancy":
                return activated ? "mdi:home" : "mdi:home-outline"
            case "opening":
                return activated ? "mdi:crop-square" : "mdi:exit-to-app"
            case "sound":
                return activated ? "mdi:music-note-off" : "mdi:music-note"
            case "vibration":
                return activated ? "mdi:crop-portrait" : "mdi:vibrate"
            case "gas", "power", "safety", "smoke":
                return activated ? "mdi:verified" : "mdi:alert"
            default:
                return activated ? "mdi:radiobox-blank" : "mdi:checkbox-marked-circle"
            }
        } else {
            if activated {
                return "mdi:radiobox-blank"
            } else {
                return "mdi:checkbox-marked-circle"
            }
        }
    }

    override var EntityColor: UIColor {
        return self.State == "on" ? UIColor.onColor : self.DefaultEntityUIColor
    }
}

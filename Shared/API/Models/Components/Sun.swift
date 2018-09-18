//
//  SunComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Sun: Entity {

    var Elevation: Float?
    var NextRising: Date?
    var NextSetting: Date?

    override func mapping(map: Map) {
        super.mapping(map: map)

        Elevation    <- map["attributes.elevation"]
        NextRising   <- (map["attributes.next_rising"], HomeAssistantTimestampTransform())
        NextSetting  <- (map["attributes.next_setting"], HomeAssistantTimestampTransform())
    }

    override var EntityColor: UIColor {
        return self.State == "above_horizon" ? UIColor.onColor : self.DefaultEntityUIColor
    }

    override var ComponentIcon: String {
        return "mdi:white-balance-sunny"
    }
}

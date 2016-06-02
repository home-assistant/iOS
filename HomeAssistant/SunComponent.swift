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
    var NextRising: NSDate?
    var NextSetting: NSDate?
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        Elevation    <- map["attributes.elevation"]
        NextRising   <- (map["attributes.next_rising"], CustomDateFormatTransform(formatString: "HH:mm:ss dd-MM-YYYY"))
        NextSetting  <- (map["attributes.next_setting"], CustomDateFormatTransform(formatString: "HH:mm:ss dd-MM-YYYY"))
    }
    
    override func EntityColor() -> UIColor {
        return self.State == "above_horizon" ? colorWithHexString("#DCC91F", alpha: 1) : self.DefaultEntityUIColor
    }
    
    override var ComponentIcon: String {
        return "mdi:white-balance-sunny"
    }
}
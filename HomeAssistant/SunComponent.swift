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
    
    required init?(_ map: Map) {
        super.init(map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        Elevation    <- map["attributes.elevation"]
        NextRising   <- (map["attributes.next_rising"], CustomDateFormatTransform(formatString: "HH:mm:ss dd-MM-YYYY"))
        NextSetting  <- (map["attributes.next_setting"], CustomDateFormatTransform(formatString: "HH:mm:ss dd-MM-YYYY"))
    }
}
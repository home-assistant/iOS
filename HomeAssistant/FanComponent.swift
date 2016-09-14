//
//  AutomationComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 9/14/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Fan: Entity {
    
    dynamic var Oscillating = false
    dynamic var Speed: String? = nil
    
    override func mapping(_ map: Map) {
        super.mapping(map)
        
        Oscillating <- map["attributes.oscillating"]
        Speed       <- map["attributes.speed"]
    }
    
    override var ComponentIcon: String {
        return "mdi:fan"
    }
}

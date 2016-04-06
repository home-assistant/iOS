//
//  SwitchComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Switch: Entity {
    
    var Location: String?
    var NodeID: String?
    var TodayMilliwattHours: Int?
    var CurrentPowerMilliwattHours: Int?
    
    required init?(_ map: Map) {
        super.init(map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        TodayMilliwattHours          <- map["attributes.today_mwh"]
        CurrentPowerMilliwattHours   <- map["attributes.current_power_mwh"]
        NodeID                       <- map["attributes.node_id"]
        Location                     <- map["attributes.location"]
    }
}
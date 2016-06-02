//
//  SwitchComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import RealmSwift

class Switch: SwitchableEntity {
    
    dynamic var Location: String? = nil
    dynamic var NodeID: String? = nil
    var TodayMilliwattHours = RealmOptional<Int>()
    var CurrentPowerMilliwattHours = RealmOptional<Int>()
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        TodayMilliwattHours          <- map["attributes.today_mwh"]
        CurrentPowerMilliwattHours   <- map["attributes.current_power_mwh"]
        NodeID                       <- map["attributes.node_id"]
        Location                     <- map["attributes.location"]
    }
    
    override var ComponentIcon: String {
        return "mdi:flash"
    }
}
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

class Switch: Entity {
    
    dynamic var Location: String? = nil
    dynamic var NodeID: String? = nil
    var TodayMilliwattHours = RealmOptional<Int>()
    var CurrentPowerMilliwattHours = RealmOptional<Int>()
    
    required init?(_ map: Map) {
        super.init(value: map)
    }
    
    required init() {
        super.init()
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        TodayMilliwattHours          <- map["attributes.today_mwh"]
        CurrentPowerMilliwattHours   <- map["attributes.current_power_mwh"]
        NodeID                       <- map["attributes.node_id"]
        Location                     <- map["attributes.location"]
    }
}
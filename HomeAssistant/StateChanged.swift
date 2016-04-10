//
//  StateChangedSSE.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/8/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class StateChangedEvent: SSEEvent {
    var NewState: Entity?
    var OldState: Entity?
    var EntityID: String?
    var EntityDomain: String?
    
    required init?(_ map: Map) {
        super.init(map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        NewState  <- map["data.new_state"]
        OldState  <- map["data.old_state"]
        EntityID  <- map["data.entity_id"]
        EntityDomain <- (map["data.entity_id"], EntityIDToDomainTransform())
    }
}
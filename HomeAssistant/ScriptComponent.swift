//
//  ScriptComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Script: Entity {
    
    var IsOn: Bool?
    var CanCancel: Bool?
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        IsOn      <- (map["state"], onOffStateTransform)
        CanCancel <- map["attributes.can_cancel"]
    }
}
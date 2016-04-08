//
//  BinarySensorComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

let onOffStateTransform = TransformOf<Bool, String>(fromJSON: { (value: String?) -> Bool? in
    return Bool(String(value!) == "on")
    }, toJSON: { (value: Bool?) -> String? in
        if let value = value {
            if value == true {
                return "on"
            } else {
                return "off"
            }
        }
        return nil
})


class BinarySensor: Entity {
    
    var IsOn: Bool?
    
    required init?(_ map: Map) {
        super.init(value: map)
    }
    
    required init() {
        super.init()
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        IsOn    <- (map["state"], onOffStateTransform)
    }
}
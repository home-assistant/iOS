//
//  LockComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

let isLockedTransform = TransformOf<Bool, String>(fromJSON: { (value: String?) -> Bool? in
    return Bool(String(value!) == "locked")
}, toJSON: { (value: Bool?) -> String? in
    if let value = value {
        if value == true {
            return "locked"
        } else {
            return "unlocked"
        }
    }
    return nil
})


class Lock: Entity {
    
    var IsLocked: Bool?

    override func mapping(map: Map) {
        super.mapping(map)
        
        IsLocked    <- (map["state"], isLockedTransform)
    }
    
    override var ComponentIcon: String {
        return "mdi:lock-open"
    }
    
    override func StateIcon() -> String {
        return (self.State == "unlocked") ? "mdi:lock-open" : "mdi:lock"
    }
}
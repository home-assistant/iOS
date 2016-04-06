//
//  GarageDoorComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

let garageIsOpenTransform = TransformOf<Bool, String>(fromJSON: { (value: String?) -> Bool? in
    return Bool(String(value!) == "open")
    }, toJSON: { (value: Bool?) -> String? in
        if let value = value {
            if value == true {
                return "open"
            } else {
                return "closed"
            }
        }
        return nil
})


class GarageDoor: Entity {
    
    var IsOpen: Bool?
    
    required init?(_ map: Map) {
        super.init(map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        IsOpen    <- (map["state"], garageIsOpenTransform)
    }
}
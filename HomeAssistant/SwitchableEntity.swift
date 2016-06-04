//
//  SwitchableEntity.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 6/3/16.
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


class SwitchableEntity: Entity {
    
    var IsOn: Bool?
    
    required init?(_ map: Map) {
        super.init(map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        IsOn         <- (map["state"], onOffStateTransform)
    }
    
    override func EntityColor() -> UIColor {
        return self.State == "on" ? colorWithHexString("#DCC91F", alpha: 1) : self.DefaultEntityUIColor
    }
}
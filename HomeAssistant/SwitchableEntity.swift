//
//  SwitchableEntity.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 6/3/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import Realm
import RealmSwift

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
    
    // MARK: - Requireds - https://github.com/Hearst-DD/ObjectMapper/issues/462
    required init() { super.init() }
    required init?(_ map: Map) { super.init() }
    required init(value: AnyObject, schema: RLMSchema) { super.init(value: value, schema: schema) }
    required init(realm: RLMRealm, schema: RLMObjectSchema) { super.init(realm: realm, schema: schema) }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        IsOn         <- (map["state"], onOffStateTransform)
    }
    
    override func EntityColor() -> UIColor {
        return self.State == "on" ? colorWithHexString("#DCC91F", alpha: 1) : self.DefaultEntityUIColor
    }
}
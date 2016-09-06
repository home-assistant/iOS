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

class SwitchableEntity: Entity {
    
    var IsOn: Bool?
    
    // MARK: - Requireds - https://github.com/Hearst-DD/ObjectMapper/issues/462
    required init() { super.init() }
    required init?(_ map: Map) { super.init() }
    required init(value: AnyObject, schema: RLMSchema) { super.init(value: value, schema: schema) }
    required init(realm: RLMRealm, schema: RLMObjectSchema) { super.init(realm: realm, schema: schema) }
    
    override func mapping(_ map: Map) {
        super.mapping(map)
        
        IsOn         <- (map["state"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
    }
    
    override func EntityColor() -> UIColor {
        return self.State == "on" ? colorWithHexString("#DCC91F", alpha: 1) : self.DefaultEntityUIColor
    }
}

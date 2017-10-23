//
//  LockComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Lock: Entity {

    @objc dynamic var IsLocked: Bool = false

    override func mapping(map: Map) {
        super.mapping(map: map)

        IsLocked    <- (map["state"], ComponentBoolTransform(trueValue: "locked", falseValue: "unlocked"))
    }

    override var ComponentIcon: String {
        return "mdi:lock-open"
    }

    override func StateIcon() -> String {
        return (self.State == "unlocked") ? "mdi:lock-open" : "mdi:lock"
    }
}

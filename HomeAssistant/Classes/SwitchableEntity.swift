//
//  SwitchableEntity.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 6/3/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class SwitchableEntity: Entity {

    var IsOn: Bool?

    override func mapping(map: Map) {
        super.mapping(map: map)

        IsOn         <- (map["state"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
    }

    override var EntityColor: UIColor {
        return self.State == "on" ? colorWithHexString("#DCC91F", alpha: 1) : self.DefaultEntityUIColor
    }
}

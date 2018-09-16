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

    var isOn: Bool?

    override func mapping(map: Map) {
        super.mapping(map: map)

        isOn <- (map["state"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
    }

    override var EntityColor: UIColor {
        return self.State == "on" ? UIColor.onColor : self.DefaultEntityUIColor
    }
}

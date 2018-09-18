//
//  InputBooleanComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class InputBoolean: Entity {
    @objc dynamic var IsOn: Bool = false

    override func mapping(map: Map) {
        super.mapping(map: map)

        IsOn         <- (map["state"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
    }

    override var ComponentIcon: String {
        return "mdi:drawing"
    }

    override var EntityColor: UIColor {
        return self.State == "on" ? UIColor.onColor : self.DefaultEntityUIColor
    }
}

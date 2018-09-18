//
//  ScriptComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Script: Entity {

    @objc dynamic var IsOn: Bool = false
    @objc dynamic var CanCancel: Bool = false

    override func mapping(map: Map) {
        super.mapping(map: map)

        IsOn         <- (map["state"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        CanCancel    <- map["attributes.can_cancel"]
    }

    override var ComponentIcon: String {
        return "mdi:file-document"
    }

    override var EntityColor: UIColor {
        return self.State == "on" ? UIColor.onColor : self.DefaultEntityUIColor
    }
}

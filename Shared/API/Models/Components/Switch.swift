//
//  SwitchComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Switch: Entity {

    @objc dynamic var IsOn: Bool = false
    var TodayMilliwattHours: Int?
    var CurrentPowerMilliwattHours: Int?

    override func mapping(map: Map) {
        super.mapping(map: map)

        IsOn                               <- (map["state"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        TodayMilliwattHours          <- map["attributes.today_mwh"]
        CurrentPowerMilliwattHours   <- map["attributes.current_power_mwh"]
    }

    override var ComponentIcon: String {
        return "mdi:flash"
    }

    override var EntityColor: UIColor {
        return self.State == "on" ? UIColor.onColor : self.DefaultEntityUIColor
    }
}

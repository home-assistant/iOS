//
//  SwitchComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import RealmSwift

class Switch: Entity {

    dynamic var IsOn: Bool = false
    var TodayMilliwattHours = RealmOptional<Int>()
    var CurrentPowerMilliwattHours = RealmOptional<Int>()

    override func mapping(map: Map) {
        super.mapping(map: map)

        IsOn                               <- (map["state"], ComponentBoolTransform(trueValue: "on", falseValue: "off"))
        TodayMilliwattHours.value          <- map["attributes.today_mwh"]
        CurrentPowerMilliwattHours.value   <- map["attributes.current_power_mwh"]
    }

    override var ComponentIcon: String {
        return "mdi:flash"
    }

     override var EntityColor: UIColor {
        return self.State == "on" ? colorWithHexString("#DCC91F", alpha: 1) : self.DefaultEntityUIColor
    }
}

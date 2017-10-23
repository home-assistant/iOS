//
//  SensorComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Sensor: Entity {

    @objc dynamic var SensorClass: String?

    override func mapping(map: Map) {
        super.mapping(map: map)

        SensorClass       <- map["attributes.sensor_class"]
    }

    override var ComponentIcon: String {
        return "mdi:eye"
    }

}

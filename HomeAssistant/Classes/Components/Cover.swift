//
//  Cover.swift
//  HomeAssistant
//
//  Created by Will Herndon on 3/1/17.
//  Copyright © 2017 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Cover: Entity {

    dynamic var IsOpen: Bool = false

    override func mapping(map: Map) {
        super.mapping(map: map)

        IsOpen     <- (map["state"], ComponentBoolTransform(trueValue: "open", falseValue: "closed"))
    }

    override var ComponentIcon: String {
        return "mdi:glassdoor"
    }
}

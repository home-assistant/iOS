//
//  InputSlider.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 9/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class InputSlider: Entity {

    var Minimum: Float?
    var Maximum: Float?
    var Step: Int?

    override func mapping(map: Map) {
        super.mapping(map: map)

        Maximum          <- map["attributes.max"]
        Minimum          <- map["attributes.min"]
        Step             <- map["attributes.step"]
    }

    override var ComponentIcon: String {
        return "mdi:ray-vertex"
    }

    func SelectValue(_ value: Float) {
        _ = HomeAssistantAPI.authenticatedAPI()?.callService(domain: "input_slider",
                                                             service: "select_value",
                                                             serviceData: ["entity_id": self.ID as AnyObject,
                                                                           "value": value as AnyObject
            ]
        )
    }
}

//
//  InputSlider.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 9/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import RealmSwift

class InputSlider: Entity {

    var Minimum = RealmOptional<Float>()
    var Maximum = RealmOptional<Float>()
    var Step = RealmOptional<Int>()

    override func mapping(map: Map) {
        super.mapping(map: map)

        Maximum.value          <- map["attributes.max"]
        Minimum.value          <- map["attributes.min"]
        Step.value             <- map["attributes.step"]
    }

    override var ComponentIcon: String {
        return "mdi:ray-vertex"
    }

    func SelectValue(_ value: Float) {
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "input_slider", service: "select_value", serviceData: ["entity_id": self.ID as AnyObject, "value": value as AnyObject])
    }
}

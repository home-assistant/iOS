//
//  InputSelectComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class InputSelect: Entity {

    var Options = [String]()

    override func mapping(map: Map) {
        super.mapping(map: map)

        Options          <- map["attributes.options"]
    }

    override var ComponentIcon: String {
        return "mdi:format-list-bulleted"
    }
}

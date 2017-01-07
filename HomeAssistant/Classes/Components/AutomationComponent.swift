//
//  AutomationComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 9/14/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Automation: Entity {

    dynamic var LastTriggered: Date? = nil

    override func mapping(map: Map) {
        super.mapping(map: map)

        LastTriggered <- (map["attributes.last_triggered"], HomeAssistantTimestampTransform())
    }

    override var ComponentIcon: String {
        return "mdi:playlist-play"
    }
}

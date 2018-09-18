//
//  WeblinkComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class Weblink: Entity {

    var URL: String?

    override func mapping(map: Map) {
        super.mapping(map: map)

        URL    <- map["attributes.url"]
    }

    override var ComponentIcon: String {
        return "mdi:open-in-new"
    }
}

//
//  Events.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class EventsResponse: Mappable {
    var Event: String?
    var ListenerCount: Int?

    required init?(map: Map) {

    }

    func mapping(map: Map) {
        Event          <- map["event"]
        ListenerCount  <- map["listener_count"]
    }
}

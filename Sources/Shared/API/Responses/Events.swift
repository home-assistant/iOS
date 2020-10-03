//
//  Events.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

public class EventsResponse: Mappable {
    public var Event: String?
    public var ListenerCount: Int?

    public required init?(map: Map) {

    }

    public func mapping(map: Map) {
        Event          <- map["event"]
        ListenerCount  <- map["listener_count"]
    }
}

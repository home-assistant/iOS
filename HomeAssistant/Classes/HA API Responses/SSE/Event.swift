//
//  Event.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/8/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class SSEEvent: StaticMappable {
    var EventType: String = ""
    var TimeFired: Date?
    var Origin: String?

    init() {}

    public static func objectForMapping(map: Map) -> BaseMappable? {
        if let eventType: String = map["event_type"].value() {
            switch eventType {
            case "state_changed":
                return StateChangedEvent()
            case "call_service":
                return CallServiceEvent()
            case "service_executed":
                return ServiceExecutedEvent()
            default:
                print("No SSE Event ObjectMapper found for:", eventType)
                return nil
            }
        }
        return nil
    }

    func mapping(map: Map) {
        EventType <- map["event_type"]
        TimeFired <- (map["time_fired"], HomeAssistantTimestampTransform())
        Origin    <- map["origin"]
    }
}

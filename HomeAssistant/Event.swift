//
//  Event.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/8/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class SSEEvent: MappableCluster {
    var Type: String = ""
    var TimeFired: NSDate?
    var Origin: String?
    
    required init?(_ map: Map){
        
    }
    
    static func objectForMapping(map: Map) -> Mappable? {
        if let eventType: String = map["event_type"].value() {
            switch eventType {
            case "state_changed":
                return StateChangedEvent(map)
            case "call_service":
                return CallServiceEvent(map)
            case "service_executed":
                return ServiceExecutedEvent(map)
            default:
                print("No SSE Event ObjectMapper found for:", eventType)
                return nil
            }
        }
        return nil
    }
    
    func mapping(map: Map) {
        Type      <- map["event_type"]
        TimeFired <- (map["time_fired"], CustomDateFormatTransform(formatString: "HH:mm:ss dd-MM-YYYY"))
        Origin    <- map["origin"]
    }
}
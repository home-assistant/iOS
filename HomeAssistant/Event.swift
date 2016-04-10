//
//  Event.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/8/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class SSEEvent: Mappable {
    var Type: String = ""
    var TimeFired: NSDate?
    var Origin: String = ""
    
    required init?(_ map: Map){
        
    }
    
    static func objectForMapping(map: Map) -> Mappable? {
        if let eventType: String = map["event_type"].value() {
            switch eventType {
            case "state_changed":
                return StateChangedEvent(map)
            default:
                print("No ObjectMapper found for:", eventType)
                return nil
            }
        }
        return nil
    }
    
    func mapping(map: Map) {
        Type <- map["event_type"]
        TimeFired <- (map["time_fired"], CustomDateFormatTransform(formatString: "HH:mm:ss dd-MM-YYYY"))
        Origin    <- map["origin"]
    }
}
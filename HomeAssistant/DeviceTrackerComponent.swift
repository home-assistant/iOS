//
//  DeviceTrackerComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

let isHomeStateTransform = TransformOf<Bool, String>(fromJSON: { (value: String?) -> Bool? in
    return Bool(String(value!) == "home")
    }, toJSON: { (value: Bool?) -> String? in
        if let value = value {
            if value == true {
                return "home"
            } else {
                return "not_home"
            }
        }
        return nil
})

class DeviceTracker: Entity {
    
    var Latitude: Float?
    var Longitude: Float?
    var Battery: Int?
    var GPSAccuracy: Int?
    var IsHome: Bool?
    
    required init?(_ map: Map) {
        super.init(value: map)
    }
    
    required init() {
        super.init()
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        Latitude     <- map["attributes.latitude"]
        Longitude    <- map["attributes.longitude"]
        Battery      <- map["attributes.battery"]
        GPSAccuracy  <- map["attributes.gps_accuracy"]
        IsHome       <- (map["state"], isHomeStateTransform)
    }
}
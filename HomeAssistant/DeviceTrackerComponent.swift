//
//  DeviceTrackerComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import RealmSwift
import CoreLocation

class DeviceTracker: Entity {
    
    var Latitude = RealmOptional<Double>()
    var Longitude = RealmOptional<Double>()
    var Battery = RealmOptional<Int>()
    var GPSAccuracy = RealmOptional<Double>() // It's a double for direct use in CLLocationDistance
    dynamic var IsHome: Bool = false
    
    override func mapping(_ map: Map) {
        super.mapping(map)
        
        Latitude     <- map["attributes.latitude"]
        Longitude    <- map["attributes.longitude"]
        Battery      <- map["attributes.battery"]
        GPSAccuracy  <- map["attributes.gps_accuracy"]
        IsHome       <- (map["state"], ComponentBoolTransform(trueValue: "home", falseValue: "not_home"))
    }
    
    func locationCoordinates() -> CLLocationCoordinate2D {
        if self.Latitude.value != nil && self.Longitude.value != nil {
            return CLLocationCoordinate2D(latitude: self.Latitude.value!, longitude: self.Longitude.value!)
        } else {
            return CLLocationCoordinate2D()
        }
    }
    
    override var ComponentIcon: String {
        return "mdi:account"
    }
}

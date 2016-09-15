//
//  ZoneComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/10/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import CoreLocation

class Zone: Entity {
    
    dynamic var Latitude:Double = 0.0
    dynamic var Longitude:Double = 0.0
    dynamic var Radius:Double = 0.0
    dynamic var trackingEnabled = true
    dynamic var enterNotification = true
    dynamic var exitNotification = true
    
    override func mapping(_ map: Map) {
        super.mapping(map)
        
        Latitude  <- map["attributes.latitude"]
        Longitude <- map["attributes.longitude"]
        Radius    <- map["attributes.radius"]
    }
    
    func locationCoordinates() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: CLLocationDegrees(self.Latitude), longitude: CLLocationDegrees(self.Longitude))
    }
    
    func location() -> CLLocation {
        return CLLocation(coordinate: self.locationCoordinates(), altitude: 0, horizontalAccuracy: self.Radius, verticalAccuracy: -1, timestamp: Date())
    }
}

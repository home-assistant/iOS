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
    
    var Latitude: Double?
    var Longitude: Double?
    var Radius: Double?
    
    override func mapping(_ map: Map) {
        super.mapping(map)
        
        Latitude  <- map["attributes.latitude"]
        Longitude <- map["attributes.longitude"]
        Radius    <- map["attributes.radius"]
    }
    
    func locationCoordinates() -> CLLocationCoordinate2D {
        if self.Latitude != nil && self.Longitude != nil {
            return CLLocationCoordinate2D(latitude: self.Latitude!, longitude: self.Longitude!)
        } else {
            return CLLocationCoordinate2D()
        }
    }
}

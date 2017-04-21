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

    dynamic var Latitude: Double = 0.0
    dynamic var Longitude: Double = 0.0
    dynamic var Radius: Double = 0.0
    dynamic var TrackingEnabled = true
    dynamic var enterNotification = true
    dynamic var exitNotification = true

    // Beacons
    dynamic var UUID: String?
    var Major: Int?
    var Minor: Int?

    override func mapping(map: Map) {
        super.mapping(map: map)

        Latitude           <- map["attributes.latitude"]
        Longitude          <- map["attributes.longitude"]
        Radius             <- map["attributes.radius"]
        TrackingEnabled    <- map["attributes.track_ios"]
        UUID               <- map["attributes.beacon.uuid"]
        Major              <- map["attributes.beacon.major"]
        Minor              <- map["attributes.beacon.minor"]
    }

    func locationCoordinates() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: CLLocationDegrees(self.Latitude),
                                      longitude: CLLocationDegrees(self.Longitude))
    }

    func location() -> CLLocation {
        return CLLocation(coordinate: self.locationCoordinates(),
                          altitude: 0,
                          horizontalAccuracy: self.Radius,
                          verticalAccuracy: -1,
                          timestamp: Date())
    }
}

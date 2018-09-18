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

public class Zone: Entity {

    @objc public dynamic var Latitude: Double = 0.0
    @objc public dynamic var Longitude: Double = 0.0
    @objc public dynamic var Radius: Double = 0.0
    @objc public dynamic var TrackingEnabled = true
    @objc public dynamic var enterNotification = true
    @objc public dynamic var exitNotification = true

    // Beacons
    @objc public dynamic var UUID: String?
    public var Major: Int?
    public var Minor: Int?

    public override func mapping(map: Map) {
        super.mapping(map: map)

        Latitude           <- map["attributes.latitude"]
        Longitude          <- map["attributes.longitude"]
        Radius             <- map["attributes.radius"]
        TrackingEnabled    <- map["attributes.track_ios"]
        UUID               <- map["attributes.beacon.uuid"]
        Major              <- map["attributes.beacon.major"]
        Minor              <- map["attributes.beacon.minor"]
    }

    public func locationCoordinates() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: CLLocationDegrees(self.Latitude),
                                      longitude: CLLocationDegrees(self.Longitude))
    }

    public func location() -> CLLocation {
        return CLLocation(coordinate: self.locationCoordinates(),
                          altitude: 0,
                          horizontalAccuracy: self.Radius,
                          verticalAccuracy: -1,
                          timestamp: Date())
    }
}

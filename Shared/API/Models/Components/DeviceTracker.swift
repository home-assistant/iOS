//
//  DeviceTrackerComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import CoreLocation

public class DeviceTracker: Entity {

    public var Latitude: Double?
    public var Longitude: Double?
    public var Battery: Int?
    public var GPSAccuracy: Double? // It's a double for direct use in CLLocationDistance
    @objc public dynamic var IsHome: Bool = false

    public override func mapping(map: Map) {
        super.mapping(map: map)

        Latitude     <- map["attributes.latitude"]
        Longitude    <- map["attributes.longitude"]
        Battery      <- map["attributes.battery"]
        GPSAccuracy  <- map["attributes.gps_accuracy"]
        IsHome       <- (map["state"], ComponentBoolTransform(trueValue: "home", falseValue: "not_home"))
    }

    public func locationCoordinates() -> CLLocationCoordinate2D {
        if self.Latitude != nil && self.Longitude != nil {
            return CLLocationCoordinate2D(latitude: self.Latitude!, longitude: self.Longitude!)
        } else {
            return CLLocationCoordinate2D()
        }
    }

    public func location() -> CLLocation {
        if let accr = self.GPSAccuracy {
            return CLLocation(coordinate: self.locationCoordinates(),
                              altitude: 0,
                              horizontalAccuracy: accr,
                              verticalAccuracy: -1,
                              timestamp: Date())
        } else {
            if self.Latitude != nil && self.Longitude != nil {
                return CLLocation(latitude: self.Latitude!, longitude: self.Longitude!)
            } else {
                return CLLocation()
            }
        }
    }

    public override var ComponentIcon: String {
        return "mdi:account"
    }
}

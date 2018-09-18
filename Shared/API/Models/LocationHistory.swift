//
//  LocationHistory.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 6/13/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import RealmSwift
import CoreLocation

public class LocationHistoryEntry: Object {
    @objc public dynamic var Trigger: String?
    @objc public dynamic var Zone: RLMZone?
    @objc public dynamic var Latitude = 0.0
    @objc public dynamic var Longitude = 0.0
    @objc public dynamic var Accuracy = 0.0
    @objc public dynamic var Payload: String = ""
    @objc public dynamic var CreatedAt = Date()

    public convenience init(updateType: LocationUpdateTrigger, location: CLLocation?, zone: RLMZone?,
                     payload: String) {
        self.init()

        var loc = CLLocation()
        if let location = location {
            loc = location
        } else if let zone = zone {
            loc = zone.location()
        }

        self.Accuracy = loc.horizontalAccuracy
        self.Latitude = loc.coordinate.latitude
        self.Longitude = loc.coordinate.longitude
        self.Trigger = String(describing: updateType)
        self.Zone = zone
        self.Payload = payload
    }

    public var clLocation: CLLocation {
        return CLLocation(latitude: self.Latitude, longitude: self.Longitude)
    }
}

public class LocationError: Object {
    @objc public dynamic var Code: Int = 0
    @objc public dynamic var Description: String = ""
    @objc public dynamic var CreatedAt = Date()

    public convenience init(err: CLError) {
        self.init()
        self.Code = err.errorCode
        self.Description = err.debugDescription
    }
}

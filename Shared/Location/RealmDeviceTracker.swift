//
//  RealmDeviceTracker.swift
//  Shared
//
//  Created by Robert Trencheny on 10/3/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import RealmSwift
import ObjectMapper
import CoreLocation
import Iconic

public class RLMDeviceTracker: Object {

    @objc public dynamic var ID: String = ""
    @objc public dynamic var FriendlyName: String?
    @objc public dynamic var Latitude: Double = 0.0
    @objc public dynamic var Longitude: Double = 0.0
    @objc public dynamic var Battery: Int = 0
    @objc public dynamic var GPSAccuracy: Double = 0 // It's a double for direct use in CLLocationDistance
    @objc public dynamic var IsHome: Bool = false

    public func mapping(map: Map) {
        ID                <- map["entity_id"]
        FriendlyName      <- map["attributes.friendly_name"]

        Latitude     <- map["attributes.latitude"]
        Longitude    <- map["attributes.longitude"]
        Battery      <- map["attributes.battery"]
        GPSAccuracy  <- map["attributes.gps_accuracy"]
        IsHome       <- (map["state"], ComponentBoolTransform(trueValue: "home", falseValue: "not_home"))
    }

    convenience init(_ device: DeviceTracker) {
        self.init()
        self.ID = device.ID
        self.FriendlyName = device.FriendlyName
        if let latitude = device.Latitude {
            self.Latitude = latitude
        }
        if let longitude = device.Longitude {
            self.Longitude = longitude
        }
        if let battery = device.Battery {
            self.Battery = battery
        }
        if let gpsAccuracy = device.GPSAccuracy {
            self.GPSAccuracy = gpsAccuracy
        }
        self.IsHome = device.IsHome
    }

    public func locationCoordinates() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.Latitude, longitude: self.Longitude)
    }

    public func location() -> CLLocation {
        if self.GPSAccuracy > -1 {
            return CLLocation(coordinate: self.locationCoordinates(),
                              altitude: 0,
                              horizontalAccuracy: self.GPSAccuracy,
                              verticalAccuracy: -1,
                              timestamp: Date())
        } else {
            return CLLocation(latitude: self.Latitude, longitude: self.Longitude)
        }
    }

    public var Domain: String {
        return self.ID.components(separatedBy: ".")[0]
    }

    public var Name: String {
        if let friendly = self.FriendlyName {
            return friendly
        } else {
            return self.ID.replacingOccurrences(of: "\(self.Domain).",
                with: "").replacingOccurrences(of: "_",
                                               with: " ").capitalized
        }
    }

    public var EntityIcon: UIImage {
        return MaterialDesignIcons.accountIcon.image(ofSize: CGSize(width: 30, height: 30),
                                                     color: UIColor(red: 0.27, green: 0.45, blue: 0.62, alpha: 1.0))
    }

    public override static func primaryKey() -> String? {
        return "ID"
    }
}

//
//  DeviceTrackerSee.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 6/13/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import CoreLocation

class DeviceTrackerSee: Mappable {

    var Accuracy: CLLocationAccuracy?
    var Attributes: [String: Any] = [:]
    var Battery: Float = 0.0
    var DeviceID: String?
    var Hostname: String?
    var Location: CLLocationCoordinate2D?
    var SourceType: UpdateTypes = .GlobalPositioningSystem

    // Attributes

    var Speed: CLLocationSpeed?
    var Altitude: CLLocationDistance?
    var Course: CLLocationDirection?
    var VerticalAccuracy: CLLocationAccuracy?
    var Trigger: LocationUpdateTrigger = .Unknown
    var Timestamp: Date?

    var ArrivalDate: Date?
    var DepartureDate: Date?

    var ActivityType: String?
    var ActivityConfidence: String?

    init() {}

    required init?(map: Map) {}

    convenience init(location: CLLocation) {
        self.init()
        self.Accuracy = location.horizontalAccuracy
        self.Location = location.coordinate
        self.Speed = location.speed
        self.Altitude = location.altitude
        self.Course = location.course
        self.VerticalAccuracy = location.verticalAccuracy
        self.Timestamp = location.timestamp
    }

    // Mappable
    func mapping(map: Map) {
        Attributes           <- map["attributes"]
        Battery              <- (map["battery"], FloatToIntTransform())
        DeviceID             <- map["dev_id"]
        Location             <- (map["gps"], CLLocationCoordinate2DTransform())
        Accuracy             <- map["gps_accuracy"]
        Hostname             <- map["host_name"]
        SourceType           <- (map["source_type"], EnumTransform<UpdateTypes>())

        Speed                <- map["attributes.speed"]
        Altitude             <- map["attributes.altitude"]
        Course               <- map["attributes.course"]
        VerticalAccuracy     <- map["attributes.vertical_accuracy"]
        Trigger              <- (map["attributes.trigger"], EnumTransform<LocationUpdateTrigger>())
        Timestamp            <- (map["attributes.timestamp"], HomeAssistantTimestampTransform())

        ArrivalDate          <- (map["attributes.arrival_date"], HomeAssistantTimestampTransform())
        DepartureDate        <- (map["attributes.departure_date"], HomeAssistantTimestampTransform())

        ActivityType         <- map["attributes.activity_type"]
        ActivityConfidence   <- map["attributes.activity_confidence"]
    }
}

enum UpdateTypes: String {
    case GlobalPositioningSystem = "gps"
    case Router = "router"
    case Bluetooth = "bluetooth"
    case BluetoothLowEnergy = "bluetooth_le"
}

open class FloatToIntTransform: TransformType {
    public typealias Object = Float
    public typealias JSON = Int

    public init() {}

    open func transformFromJSON(_ value: Any?) -> Float? {
        if let int = value as? Int {
            return Float(int / 100)
        }
        return nil
    }

    open func transformToJSON(_ value: Float?) -> Int? {
        guard let value = value else { return nil }
        return Int(value * 100)
    }
}

open class CLLocationCoordinate2DTransform: TransformType {
    public typealias Object = CLLocationCoordinate2D
    public typealias JSON = [Double]

    public init() {}

    open func transformFromJSON(_ value: Any?) -> CLLocationCoordinate2D? {
        if let loc = value as? [Double] {
            return CLLocationCoordinate2D(latitude: loc[0], longitude: loc[1])
        }
        return nil
    }

    open func transformToJSON(_ value: CLLocationCoordinate2D?) -> [Double]? {
        guard let value = value else { return nil }
        return value.toArray()
    }
}

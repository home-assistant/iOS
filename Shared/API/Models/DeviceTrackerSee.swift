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
import CoreMotion

public class DeviceTrackerSee: Mappable {

    public var HorizontalAccuracy: CLLocationAccuracy?
    public var Attributes: [String: Any] = [:]
    public var Battery: Float = 0.0
    public var DeviceID: String?
    public var Hostname: String?
    public var Location: CLLocationCoordinate2D?
    public var SourceType: UpdateTypes = .GlobalPositioningSystem
    public var LocationName: String?
    public var ConsiderHome: TimeInterval?

    // Attributes
    public var Speed: CLLocationSpeed?
    public var Altitude: CLLocationDistance?
    public var Course: CLLocationDirection?
    public var VerticalAccuracy: CLLocationAccuracy?
    public var Trigger: LocationUpdateTrigger = .Unknown
    public var Timestamp: Date?
    public var Floor: Int?

    // CMMotionActivity
    public var ActivityType: String?
    public var ActivityConfidence: String?
    public var ActivityStartDate: Date?

    init() {}

    public required init?(map: Map) {}

    public convenience init(trigger: LocationUpdateTrigger, location: CLLocation?, zone: RLMZone?) {
        self.init()

        self.Trigger = trigger
        self.SourceType = (self.Trigger == .BeaconRegionEnter || self.Trigger == .BeaconRegionExit
            ? .BluetoothLowEnergy : .GlobalPositioningSystem)

        if let location = location, (trigger != .BeaconRegionEnter && trigger != .BeaconRegionExit) {
            self.SetLocation(location: location)
        } else if let zone = zone {
            self.SetZone(zone: zone)
        }
    }

    public func SetZone(zone: RLMZone) {
        self.HorizontalAccuracy = zone.Radius
        self.Location = zone.locationCoordinates()

        if zone.ID == "zone.home" {
            switch self.Trigger {
            case .RegionEnter, .GPSRegionEnter, .BeaconRegionEnter:
                self.LocationName = LocationNames.Home.rawValue
            case .RegionExit, .GPSRegionExit:
                self.LocationName =  LocationNames.NotHome.rawValue
            case .BeaconRegionExit:
                self.ConsiderHome = TimeInterval(exactly: 180)
                self.ClearLocation()
            default:
                break
            }
        } else {
            switch self.Trigger {
            case .BeaconRegionEnter:
                self.LocationName = zone.Name
            case .BeaconRegionExit:
                break
            default:
                break
            }
        }
    }

    public func SetLocation(location: CLLocation) {
        self.HorizontalAccuracy = location.horizontalAccuracy
        self.Location = location.coordinate
        self.Speed = location.speed
        self.Altitude = location.altitude
        self.Course = location.course
        self.VerticalAccuracy = location.verticalAccuracy
        self.Timestamp = location.timestamp
        self.Floor = location.floor?.level
    }

    public func SetActivity(activity: CMMotionActivity) {
        self.ActivityType = activity.activityType
        self.ActivityConfidence = activity.confidence.description
        self.ActivityStartDate = activity.startDate
    }

    public func ClearLocation() {
        self.HorizontalAccuracy = nil
        self.Location = nil
        self.Speed = nil
        self.Altitude = nil
        self.Course = nil
        self.VerticalAccuracy = nil
        self.Timestamp = nil
    }

    public var cllocation: CLLocation? {
        if let location = self.Location, let altitude = self.Altitude, let hAccuracy = self.HorizontalAccuracy,
            let vAccuracy = self.VerticalAccuracy, let timestamp = self.Timestamp {
            return CLLocation(coordinate: location, altitude: altitude, horizontalAccuracy: hAccuracy,
                              verticalAccuracy: vAccuracy, timestamp: timestamp)
        } else if let location = self.Location {
            return CLLocation(latitude: location.latitude, longitude: location.longitude)
        }
        return nil
    }

    // Mappable
    public func mapping(map: Map) {
        Attributes           <-  map["attributes"]
        Battery              <- (map["battery"], FloatToIntTransform())
        DeviceID             <-  map["dev_id"]
        Location             <- (map["gps"], CLLocationCoordinate2DTransform())
        HorizontalAccuracy   <-  map["gps_accuracy"]
        Hostname             <-  map["host_name"]
        SourceType           <- (map["source_type"], EnumTransform<UpdateTypes>())
        LocationName         <- map["location_name"]
        ConsiderHome         <- (map["consider_home"], TimeIntervalToString())

        Speed                <-  map["attributes.speed"]
        Altitude             <-  map["attributes.altitude"]
        Course               <-  map["attributes.course"]
        VerticalAccuracy     <-  map["attributes.vertical_accuracy"]
        Trigger              <- (map["attributes.trigger"], EnumTransform<LocationUpdateTrigger>())
        Timestamp            <- (map["attributes.timestamp"], HomeAssistantTimestampTransform())
        Floor                <-  map["attributes.floor"]

        ActivityType         <-  map["attributes.activity_type"]
        ActivityConfidence   <-  map["attributes.activity_confidence"]
        ActivityStartDate    <-  (map["attributes.activity_start_date"], HomeAssistantTimestampTransform())
    }
}

public enum UpdateTypes: String {
    case GlobalPositioningSystem = "gps"
    case Router = "router"
    case Bluetooth = "bluetooth"
    case BluetoothLowEnergy = "bluetooth_le"
}

public enum LocationNames: String {
    case Home = "home"
    case NotHome = "not_home"
}

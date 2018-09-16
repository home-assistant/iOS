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

class DeviceTrackerSee: Mappable {

    var HorizontalAccuracy: CLLocationAccuracy?
    var Attributes: [String: Any] = [:]
    var Battery: Float = 0.0
    var DeviceID: String?
    var Hostname: String?
    var Location: CLLocationCoordinate2D?
    var SourceType: UpdateTypes = .GlobalPositioningSystem
    var LocationName: LocationNames?
    var ConsiderHome: TimeInterval?

    // Attributes
    var Speed: CLLocationSpeed?
    var Altitude: CLLocationDistance?
    var Course: CLLocationDirection?
    var VerticalAccuracy: CLLocationAccuracy?
    var Trigger: LocationUpdateTrigger = .Unknown
    var Timestamp: Date?
    var Floor: Int?

    // CLVisit
    var ArrivalDate: Date?
    var DepartureDate: Date?

    // CMMotionActivity
    var ActivityType: String?
    var ActivityConfidence: String?
    var ActivityStartDate: Date?

    init() {}

    required init?(map: Map) {}

    convenience init(trigger: LocationUpdateTrigger, location: CLLocation?, visit: CLVisit?, zone: RLMZone?) {
        self.init()

        self.Trigger = trigger
        self.SourceType = (self.Trigger == .BeaconRegionEnter || self.Trigger == .BeaconRegionExit
            ? .BluetoothLowEnergy : .GlobalPositioningSystem)

        if let location = location {
            self.SetLocation(location: location)
        } else if let visit = visit {
            self.SetVisit(visit: visit)
        } else if let zone = zone {
            self.SetZone(zone: zone)
        }
    }

    func SetVisit(visit: CLVisit) {
        self.HorizontalAccuracy = visit.horizontalAccuracy
        self.Location = visit.coordinate
        if visit.arrivalDate != NSDate.distantPast {
            self.ArrivalDate = visit.arrivalDate
        }
        if visit.departureDate != NSDate.distantFuture {
            self.DepartureDate = visit.departureDate
        }
    }

    func SetZone(zone: RLMZone) {
        self.HorizontalAccuracy = zone.Radius
        self.Location = zone.locationCoordinates()

        if zone.ID == "zone.home" {
            if self.Trigger == .RegionEnter || self.Trigger == .BeaconRegionEnter {
                self.LocationName = LocationNames.Home
            } else if self.Trigger == .RegionExit {
                self.LocationName = LocationNames.NotHome
            } else if self.Trigger == .BeaconRegionExit {
                self.ConsiderHome = TimeInterval(exactly: 180)
                self.ClearLocation()
            }
        }
    }

    func SetLocation(location: CLLocation) {
        self.HorizontalAccuracy = location.horizontalAccuracy
        self.Location = location.coordinate
        self.Speed = location.speed
        self.Altitude = location.altitude
        self.Course = location.course
        self.VerticalAccuracy = location.verticalAccuracy
        self.Timestamp = location.timestamp
        self.Floor = location.floor?.level
    }

    func SetActivity(activity: CMMotionActivity) {
        self.ActivityType = activity.activityType
        self.ActivityConfidence = activity.confidence.description
        self.ActivityStartDate = activity.startDate
    }

    func ClearLocation() {
        self.HorizontalAccuracy = nil
        self.Location = nil
        self.Speed = nil
        self.Altitude = nil
        self.Course = nil
        self.VerticalAccuracy = nil
        self.Timestamp = nil
        self.ArrivalDate = nil
        self.DepartureDate = nil
    }

    var cllocation: CLLocation? {
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
    func mapping(map: Map) {
        Attributes           <-  map["attributes"]
        Battery              <- (map["battery"], FloatToIntTransform())
        DeviceID             <-  map["dev_id"]
        Location             <- (map["gps"], CLLocationCoordinate2DTransform())
        HorizontalAccuracy   <-  map["gps_accuracy"]
        Hostname             <-  map["host_name"]
        SourceType           <- (map["source_type"], EnumTransform<UpdateTypes>())
        LocationName         <- (map["location_name"], EnumTransform<LocationNames>())
        ConsiderHome         <- (map["consider_home"], TimeIntervalToString())

        Speed                <-  map["attributes.speed"]
        Altitude             <-  map["attributes.altitude"]
        Course               <-  map["attributes.course"]
        VerticalAccuracy     <-  map["attributes.vertical_accuracy"]
        Trigger              <- (map["attributes.trigger"], EnumTransform<LocationUpdateTrigger>())
        Timestamp            <- (map["attributes.timestamp"], HomeAssistantTimestampTransform())
        Floor                <-  map["attributes.floor"]

        ArrivalDate          <- (map["attributes.arrival_date"], HomeAssistantTimestampTransform())
        DepartureDate        <- (map["attributes.departure_date"], HomeAssistantTimestampTransform())

        ActivityType         <-  map["attributes.activity_type"]
        ActivityConfidence   <-  map["attributes.activity_confidence"]
        ActivityStartDate    <-  (map["attributes.activity_start_date"], HomeAssistantTimestampTransform())
    }
}

enum UpdateTypes: String {
    case GlobalPositioningSystem = "gps"
    case Router = "router"
    case Bluetooth = "bluetooth"
    case BluetoothLowEnergy = "bluetooth_le"
}

enum LocationNames: String {
    case Home = "home"
    case NotHome = "not_home"
}

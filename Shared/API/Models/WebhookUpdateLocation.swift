//
//  WebhookUpdateLocation.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 3/7/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import CoreLocation
import CoreMotion

public class WebhookUpdateLocation: Mappable {

    public var HorizontalAccuracy: CLLocationAccuracy?
    public var Battery: Int = 0
    public var Location: CLLocationCoordinate2D?
    public var SourceType: UpdateTypes = .GlobalPositioningSystem
    public var LocationName: String?

    public var Speed: CLLocationSpeed?
    public var Altitude: CLLocationDistance?
    public var Course: CLLocationDirection?
    public var VerticalAccuracy: CLLocationAccuracy?

    // Not sent
    public var Trigger: LocationUpdateTrigger = .Unknown

    init() {}

    public required init?(map: Map) {}

    public convenience init(trigger: LocationUpdateTrigger, location: CLLocation?, zone: RLMZone?) {
        self.init()

        self.SourceType = (self.Trigger == .BeaconRegionEnter || self.Trigger == .BeaconRegionExit
            ? .BluetoothLowEnergy : .GlobalPositioningSystem)

        let useLocation: Bool

        switch trigger {
        case .BeaconRegionExit, .BeaconRegionEnter:
            // never use location for beacons
            useLocation = false
        case .GPSRegionEnter where Current.settingsStore.useNewOneShotLocation == false:
            // don't use location for gps enter when not using a one-shot to get location
            // new one-shot flag controls whether we do a one-shot during region updates
            useLocation = false
        default:
            useLocation = true
        }

        if let location = location, useLocation {
            self.SetLocation(location: location)
        } else if let zone = zone {
            self.SetZone(zone: zone)
        }
    }

    public func SetZone(zone: RLMZone) {
        self.HorizontalAccuracy = zone.Radius
        self.Location = zone.locationCoordinates()

        #if os(iOS)
        // https://github.com/home-assistant/home-assistant-iOS/issues/32
        if let currentSSID = ConnectionInfo.CurrentWiFiSSID, zone.SSIDTrigger.contains(currentSSID) {
            self.LocationName = zone.Name
            return
        }
        #endif

        if zone.ID == "zone.home" {
            switch self.Trigger {
            case .RegionEnter, .GPSRegionEnter, .BeaconRegionEnter:
                self.LocationName = LocationNames.Home.rawValue
            case .RegionExit, .GPSRegionExit:
                self.LocationName =  LocationNames.NotHome.rawValue
            case .BeaconRegionExit:
                self.ClearLocation()
            default:
                break
            }
        } else {
            switch self.Trigger {
            case .BeaconRegionEnter:
                self.LocationName = zone.Name
            case .BeaconRegionExit:
                self.ClearLocation()
            default:
                break
            }
        }
    }

    public func SetLocation(location: CLLocation) {
        self.Location = location.coordinate
        if location.speed > -1 {
            self.Speed = location.speed
        }
        if location.course > -1 {
            self.Course = location.course
        }
        if location.altitude > -1 {
            self.Altitude = location.altitude
        }
        if location.verticalAccuracy > -1 {
            self.VerticalAccuracy = location.verticalAccuracy
        }
        if location.horizontalAccuracy > -1 {
            self.HorizontalAccuracy = location.horizontalAccuracy
        }
    }

    public func ClearLocation() {
        self.HorizontalAccuracy = nil
        self.Location = nil
        self.Speed = nil
        self.Altitude = nil
        self.Course = nil
        self.VerticalAccuracy = nil
    }

    public var cllocation: CLLocation? {
        if let location = self.Location, let altitude = self.Altitude, let hAccuracy = self.HorizontalAccuracy,
            let vAccuracy = self.VerticalAccuracy {
            return CLLocation(coordinate: location, altitude: altitude, horizontalAccuracy: hAccuracy,
                              verticalAccuracy: vAccuracy, timestamp: Date())
        } else if let location = self.Location {
            return CLLocation(latitude: location.latitude, longitude: location.longitude)
        }
        return nil
    }

    // Mappable
    public func mapping(map: Map) {
        Battery               <-    map["battery"]
        Location              <-   (map["gps"], CLLocationCoordinate2DTransform())
        HorizontalAccuracy    <-    map["gps_accuracy"]
        // SourceType            <-   (map["source_type"], EnumTransform<UpdateTypes>())
        LocationName          <-    map["location_name"]

        Speed                 <-    map["speed"]
        Altitude              <-    map["altitude"]
        Course                <-    map["course"]
        VerticalAccuracy      <-    map["vertical_accuracy"]
    }
}

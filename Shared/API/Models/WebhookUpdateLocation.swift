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
    public var ConsiderHome: TimeInterval?

    // Not sent
    public var Trigger: LocationUpdateTrigger = .Unknown

    init() {}

    public required init?(map: Map) {}

    public convenience init(trigger: LocationUpdateTrigger, location: CLLocation?, zone: RLMZone?) {
        self.init()

        self.SourceType = (self.Trigger == .BeaconRegionEnter || self.Trigger == .BeaconRegionExit
            ? .BluetoothLowEnergy : .GlobalPositioningSystem)

        if let location = location, (
            trigger != .BeaconRegionEnter && trigger != .BeaconRegionExit && trigger != .GPSRegionEnter) {
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
        if let currentSSID = ConnectionInfo.currentSSID(), zone.SSIDTrigger.contains(currentSSID) {
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
                self.ClearLocation()
            default:
                break
            }
        }
    }

    public func SetLocation(location: CLLocation) {
        self.HorizontalAccuracy = location.horizontalAccuracy
        self.Location = location.coordinate
    }

    public func ClearLocation() {
        self.HorizontalAccuracy = nil
        self.Location = nil
    }

    public var cllocation: CLLocation? {
        if let location = self.Location {
            return CLLocation(latitude: location.latitude, longitude: location.longitude)
        }
        return nil
    }

    // Mappable
    public func mapping(map: Map) {
        Battery               <-    map["battery"]
        Location              <-   (map["gps"], CLLocationCoordinate2DTransform())
        HorizontalAccuracy    <-    map["gps_accuracy"]
        SourceType            <-   (map["source_type"], EnumTransform<UpdateTypes>())
        LocationName          <-    map["location_name"]
        ConsiderHome          <-   (map["consider_home"], TimeIntervalToString())
    }
}

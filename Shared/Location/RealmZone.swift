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
import RealmSwift

public class RLMZone: Object {

    @objc public dynamic var ID: String = ""
    @objc public dynamic var Latitude: Double = 0.0
    @objc public dynamic var Longitude: Double = 0.0
    @objc public dynamic var Radius: Double = 0.0
    @objc public dynamic var TrackingEnabled = true
    @objc public dynamic var enterNotification = true
    @objc public dynamic var exitNotification = true
    @objc public dynamic var inRegion = false

    // Beacons
    @objc public dynamic var BeaconUUID: String?
    public let BeaconMajor = RealmOptional<Int>()
    public let BeaconMinor = RealmOptional<Int>()

    public func mapping(map: Map) {
        ID                       <- map["entity_id"]

        Latitude                 <- map["attributes.latitude"]
        Longitude                <- map["attributes.longitude"]
        Radius                   <- map["attributes.radius"]
        TrackingEnabled          <- map["attributes.track_ios"]

        BeaconUUID               <- map["attributes.beacon.uuid"]
        BeaconMajor.value        <- map["attributes.beacon.major"]
        BeaconMinor.value        <- map["attributes.beacon.minor"]
    }

    convenience init(zone: Zone) {
        self.init()
        self.ID = zone.ID
        self.Latitude = zone.Latitude
        self.Longitude = zone.Longitude
        self.Radius = zone.Radius
        self.TrackingEnabled = zone.TrackingEnabled
        self.BeaconUUID = zone.UUID
        self.BeaconMajor.value = zone.Major
        self.BeaconMinor.value = zone.Minor
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

    public func region() -> CLRegion? {
        if self.BeaconUUID != nil {
            // iBeacon
            return self.beaconRegion
        } else {
            // Geofence / CircularRegion
            return self.circularRegion()
        }
    }

    public var beaconRegion: CLBeaconRegion? {
        guard let uuidString = self.BeaconUUID else {
            return nil
        }

        guard let uuid = UUID(uuidString: uuidString) else {
            let event =
                ClientEvent(text: "Unable to create beacon region due to invalid UUID: \(uuidString)",
                    type: .locationUpdate)
            Current.clientEventStore.addEvent(event)
            print("Could create CLBeaconRegion because of invalid UUID")
            return nil
        }

        var beaconRegion = CLBeaconRegion(proximityUUID: uuid, identifier: self.ID)
        if let major = self.BeaconMajor.value, let minor = self.BeaconMinor.value {
            beaconRegion = CLBeaconRegion(
                proximityUUID: uuid,
                major: CLBeaconMajorValue(major),
                minor: CLBeaconMinorValue(minor),
                identifier: self.ID
            )
        } else if let major = self.BeaconMajor.value {
            beaconRegion = CLBeaconRegion(
                proximityUUID: uuid,
                major: CLBeaconMajorValue(major),
                identifier: self.ID
            )
        }

        beaconRegion.notifyEntryStateOnDisplay = true
        beaconRegion.notifyOnEntry = true
        beaconRegion.notifyOnExit = true
        return beaconRegion
    }

    public func circularRegion() -> CLCircularRegion {
        let region = CLCircularRegion(
            center: CLLocationCoordinate2DMake(self.Latitude, self.Longitude),
            radius: self.Radius,
            identifier: self.ID
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }

    public override static func primaryKey() -> String? {
        return "ID"
    }

    public var Name: String {
        return self.ID.replacingOccurrences(of: "\(self.Domain).",
                                            with: "").replacingOccurrences(of: "_",
                                                                           with: " ").capitalized
    }

    public var Domain: String {
        return self.ID.components(separatedBy: ".")[0]
    }

    public var isBeaconRegion: Bool {
        return self.BeaconUUID != nil
    }

    public override var debugDescription: String {
        return "Zone - ID: \(self.ID), state: " + (self.inRegion ? "inside" : "outside")
    }
}

//
//  ZoneComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/10/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import CoreLocation
import RealmSwift

public final class RLMZone: Object, UpdatableModel {

    @objc public dynamic var ID: String = ""
    @objc public dynamic var FriendlyName: String?
    @objc public dynamic var Latitude: Double = 0.0
    @objc public dynamic var Longitude: Double = 0.0
    @objc public dynamic var Radius: Double = 0.0
    @objc public dynamic var TrackingEnabled = true
    @objc public dynamic var enterNotification = true
    @objc public dynamic var exitNotification = true
    @objc public dynamic var inRegion = false
    @objc public dynamic var isPassive = false

    // Beacons
    @objc public dynamic var BeaconUUID: String?
    public let BeaconMajor = RealmOptional<Int>()
    public let BeaconMinor = RealmOptional<Int>()

    // SSID
    public var SSIDTrigger = List<String>()
    public var SSIDFilter = List<String>()

    public var isHome: Bool {
        ID == "zone.home"
    }

    static func didUpdate(objects: [RLMZone], realm: Realm) {

    }

    static func willDelete(objects: [RLMZone], realm: Realm) {

    }

    func update(with zone: Zone, using: Realm) {
        if realm == nil {
            self.ID = zone.ID
        } else {
            precondition(zone.ID == ID)
        }
        self.Latitude = zone.Latitude
        self.Longitude = zone.Longitude
        self.Radius = zone.Radius
        self.TrackingEnabled = zone.TrackingEnabled
        self.BeaconUUID = zone.UUID
        self.BeaconMajor.value = zone.Major
        self.BeaconMinor.value = zone.Minor
        self.isPassive = zone.isPassive

        self.SSIDTrigger.removeAll()
        if let ssidTrigger = zone.SSIDTrigger {
            self.SSIDTrigger.append(objectsIn: ssidTrigger)
        }
        self.SSIDFilter.removeAll()
        if let ssidFilter = zone.SSIDFilter {
            self.SSIDFilter.append(objectsIn: ssidFilter)
        }
    }

    public var center: CLLocationCoordinate2D {
        .init(
            latitude: Latitude,
            longitude: Longitude
        )
    }

    public var location: CLLocation {
        return CLLocation(coordinate: center,
                          altitude: 0,
                          horizontalAccuracy: self.Radius,
                          verticalAccuracy: -1,
                          timestamp: Date())
    }

    public var regionsForMonitoring: [CLRegion] {
        #if os(iOS)
        if let beaconRegion = beaconRegion {
            return [beaconRegion]
        } else {
            return circularRegionsForMonitoring
        }
        #else
        return circularRegionsForMonitoring
        #endif
    }

    public var circularRegion: CLCircularRegion {
        let region = CLCircularRegion(center: center, radius: Radius, identifier: ID)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }

    #if os(iOS)
    public var beaconRegion: CLBeaconRegion? {
        guard let uuidString = self.BeaconUUID else {
            return nil
        }

        guard let uuid = UUID(uuidString: uuidString) else {
            let event =
                ClientEvent(text: "Unable to create beacon region due to invalid UUID: \(uuidString)",
                    type: .locationUpdate)
            Current.clientEventStore.addEvent(event)
            Current.Log.error("Couldn't create CLBeaconRegion (\(self.ID)) because of invalid UUID: \(uuidString)")
            return nil
        }

        let beaconRegion: CLBeaconRegion

        if let major = self.BeaconMajor.value, let minor = self.BeaconMinor.value {
            if #available(iOS 13, *) {
                beaconRegion = CLBeaconRegion(
                    uuid: uuid,
                    major: CLBeaconMajorValue(major),
                    minor: CLBeaconMinorValue(minor),
                    identifier: self.ID
                )
            } else {
                beaconRegion = CLBeaconRegion(
                    proximityUUID: uuid,
                    major: CLBeaconMajorValue(major),
                    minor: CLBeaconMinorValue(minor),
                    identifier: self.ID
                )
            }
        } else if let major = self.BeaconMajor.value {
            if #available(iOS 13, *) {
                beaconRegion = CLBeaconRegion(
                    uuid: uuid,
                    major: CLBeaconMajorValue(major),
                    identifier: self.ID
                )
            } else {
                beaconRegion = CLBeaconRegion(
                    proximityUUID: uuid,
                    major: CLBeaconMajorValue(major),
                    identifier: self.ID
                )
            }
        } else {
            if #available(iOS 13, *) {
                beaconRegion = CLBeaconRegion(uuid: uuid, identifier: self.ID)
            } else {
                beaconRegion = CLBeaconRegion(proximityUUID: uuid, identifier: self.ID)
            }
        }

        beaconRegion.notifyEntryStateOnDisplay = true
        beaconRegion.notifyOnEntry = true
        beaconRegion.notifyOnExit = true
        return beaconRegion
    }
    #endif

    public var circularRegionsForMonitoring: [CLCircularRegion] {
        if Radius >= 100 {
            // zone is big enough to not have false-enters
            let region = CLCircularRegion(center: center, radius: Radius, identifier: ID)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            return [region]
        } else {
            // zone is too small for region monitoring without false-enters
            // see https://github.com/home-assistant/iOS/issues/784

            // given we're a circle centered at (lat, long) with radius R
            // and we want to be a series of circles with radius 100m that overlap our circle as best as possible
            let numberOfCircles = 3
            let minimumRadius: Double = 100.0
            let centerOffset = Measurement<UnitLength>(value: minimumRadius - Radius, unit: .meters)
            let sliceAngle = ((2.0 * Double.pi) / Double(numberOfCircles))

            let angles: [Measurement<UnitAngle>] = (0..<numberOfCircles).map { amount in
                return .init(value: sliceAngle * Double(amount), unit: .radians)
            }

            return angles.map { angle in
                return CLCircularRegion(
                    center: center.moving(distance: centerOffset, direction: angle),
                    radius: minimumRadius,
                    identifier: String(format: "%@@%03.0f", ID, angle.converted(to: .degrees).value)
                )
            }
        }
    }

    public override static func primaryKey() -> String? {
        return "ID"
    }

    public var Name: String {
        if self.isInvalidated { return "Deleted" }
        if let fName = self.FriendlyName { return fName }
        return self.ID.replacingOccurrences(of: "\(self.Domain).",
                                            with: "").replacingOccurrences(of: "_",
                                                                           with: " ").capitalized
    }

    public var Domain: String {
        return "zone"
    }

    public var isBeaconRegion: Bool {
        if self.isInvalidated { return false }
        return self.BeaconUUID != nil
    }

    public override var debugDescription: String {
        return "Zone - ID: \(self.ID), state: " + (self.inRegion ? "inside" : "outside")
    }
}

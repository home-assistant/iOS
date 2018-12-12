//
//  RegionManager.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 8/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import CoreLocation
import CoreMotion
import Foundation
import Shared
import os
import UIKit

private let kLocationMaximumAge: TimeInterval = 10.0

class RegionManager: NSObject {
    let locationManager = CLLocationManager()
    var backgroundTask: UIBackgroundTaskIdentifier?
    let activityManager = CMMotionActivityManager()
    var lastActivity: CMMotionActivity?
    var lastLocation: CLLocation?
    var oneShotLocationActive: Bool = false
    var lastLocationDate: Date = Current.date()
    var backgroundTasks: [String: UIBackgroundTaskIdentifier] = [:]

    var zones: [RLMZone] {
        let realm = Current.realm()
        return realm.objects(RLMZone.self).map { $0 }
    }

    var activeZones: [RLMZone] {
        let realm = Current.realm()
        return realm.objects(RLMZone.self).filter(NSPredicate(format: "inRegion == %@",
                                                              NSNumber(value: true))).map { $0 }
    }

    internal lazy var coreMotionQueue: OperationQueue = {
        return OperationQueue()
    }()

    override init() {
        super.init()
        let event = ClientEvent(text: "Initializing Region Manager", type: .unknown)
        Current.clientEventStore.addEvent(event)
        self.startMonitoring()
    }

    private func startMonitoring() {
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startMonitoringVisits()
        locationManager.startMonitoringSignificantLocationChanges()
        self.syncMonitoredRegions()
    }

    func triggerRegionEvent(_ manager: CLLocationManager, trigger: LocationUpdateTrigger, region: CLRegion) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            let message = "Region update failed because client is not authenticated."
            Current.clientEventStore.addEvent(ClientEvent(text: message, type: .locationUpdate))
            return
        }

        self.lastLocationDate = Current.date()
        var trig = trigger
        guard let zone = zones.zoneForRegion(region) else {
            print("Zone ID \(region.identifier) doesn't exist in Realm, syncing monitored regions now")
            syncMonitoredRegions()
            return
        }

        // Do nothing in case we don't want to trigger an enter event
        if zone.TrackingEnabled == false {
            print("Tracking enabled is false")
            return
        }

        if region is CLBeaconRegion {
            if trigger == .RegionEnter {
                trig = .BeaconRegionEnter
            }
            if trigger == .RegionExit {
                trig = .BeaconRegionExit
            }
        } else {
            if trigger == .RegionEnter {
                trig = .GPSRegionEnter
            }
            if trigger == .RegionExit {
                trig = .GPSRegionExit
            }
        }

        let taskName = "\(region.identifier)-\(trig)-\(Current.date())"
        let backgroundTimeoutHandler = {
            self.endBackgroundTaskWithName(taskName)
        }
        let task = UIApplication.shared.beginBackgroundTask(withName: taskName,
                                                            expirationHandler: backgroundTimeoutHandler)

        self.backgroundTasks[taskName] = task

        let inRegion = (trigger == .RegionEnter)
        guard zone.inRegion != inRegion else {
            let noChangeMessage = "Not updating \(zone.debugDescription) because DB already believes state " +
            "to be correct. (\(zone.inRegion ? "In" : "out")). Trigger: \(trigger)"
            print(noChangeMessage)
            Current.clientEventStore.addEvent(ClientEvent(text: noChangeMessage, type: .locationUpdate))
            return
        }

        // swiftlint:disable:next force_try
        try! zone.realm?.write {
            zone.inRegion = inRegion
        }

        let message = "Submitting location for zone \(zone.ID) with trigger \(trig.rawValue)."
        Current.clientEventStore.addEvent(ClientEvent(text: message, type: .locationUpdate))
        api.submitLocation(updateType: trig, location: self.locationManager.location, zone: zone).done {
            let message = "Succeeded updating zone \(zone.ID) with trigger \(trig.rawValue)."
            Current.clientEventStore.addEvent(ClientEvent(text: message, type: .locationUpdate))
        }.ensure {
            self.endBackgroundTaskWithName(taskName)
        }.catch { error in
            let eventName = trigger == .RegionEnter ? "Enter" : "Exit"
            let SSID = "SSID: \(ConnectionInfo.currentSSID() ?? "Unavailable")"
            let event = ClientEvent(text: "Failed to send location after region \(eventName). SSID: \(SSID)",
                type: .locationUpdate)
            Current.clientEventStore.addEvent(event)
            print("Error sending location after region trigger event: \(error)")
        }
    }

    func startMonitoring(zone: RLMZone) {
        if let beaconRegion = zone.beaconRegion {
            locationManager.startMonitoring(for: beaconRegion)
        } else {
            locationManager.startMonitoring(for: zone.circularRegion())
        }

        if Current.settingsStore.motionEnabled {
            activityManager.startActivityUpdates(to: coreMotionQueue) { [weak self] activity in
                self?.lastActivity = activity
            }
        }
    }

    @objc func syncMonitoredRegions() {
        var unmonitoredZones = Set(self.zones)
        locationManager.monitoredRegions.forEach { [weak self] region in
            let removeZone = {
                let event = ClientEvent(text: "Stopping monitoring of region \(region.identifier)",
                    type: .locationUpdate)
                print(event.text)
                Current.clientEventStore.addEvent(event)
                self?.locationManager.stopMonitoring(for: region)
            }

            guard let currentZone = zones.zoneForRegion(region) else {
                removeZone()
                return
            }

            let isBeaconRegion = region is CLBeaconRegion
            if currentZone.isBeaconRegion != isBeaconRegion {
                removeZone()
                return
            }

            if let beaconRegion = region as? CLBeaconRegion,
                (beaconRegion.proximityUUID.uuidString != currentZone.BeaconUUID ||
                    beaconRegion.minor?.intValue != currentZone.BeaconMinor.value ||
                    beaconRegion.major?.intValue != currentZone.BeaconMajor.value) {
                removeZone()
                return
            } else if let circularRegion = region as? CLCircularRegion,
                (circularRegion.center.latitude != currentZone.Latitude ||
                 circularRegion.center.longitude != currentZone.Longitude ||
                 circularRegion.radius != currentZone.Radius) {
                removeZone()
                return
            }

            // If we got here, the zone is valid.
            unmonitoredZones.remove(currentZone)
             let event = ClientEvent(text: "Already Monitoring: \(currentZone.debugDescription)",
                type: .unknown)
            Current.clientEventStore.addEvent(event)
        }

        // start monitoring for all existing regions
        unmonitoredZones.forEach { [weak self] zone in
            print("Starting monitoring of zone \(zone)")
            let event = ClientEvent(text: "Monitoring: \(zone.debugDescription)", type: .unknown)
            Current.clientEventStore.addEvent(event)
            self?.startMonitoring(zone: zone)
        }
    }

    func checkIfInsideAnyRegions(location: CLLocationCoordinate2D) -> Set<CLRegion> {
        return self.locationManager.monitoredRegions.filter { (region) -> Bool in
            if let circRegion = region as? CLCircularRegion {
                // print("Checking", circRegion.identifier)
                return circRegion.contains(location)
            }
            return false
        }
    }
}

// MARK: CLLocationManagerDelegate

extension RegionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            Current.settingsStore.locationEnabled = status == .authorizedAlways
        }
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            return
        }

        // Only process visit entrances (ignoring departures) that are recent enough.
        guard visit.departureDate == Date.distantFuture,
            abs(visit.arrivalDate.timeIntervalSinceNow) < kLocationMaximumAge else {
            print("Ignoring stale visit")
            return
        }

        let location = CLLocation(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)
        api.submitLocation(updateType: .Visit, location: location,
                           zone: nil).catch { print("Error submitting location: \($0)" )}
        self.lastLocationDate = Current.date()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            return
        }

        if Current.isPerformingSingleShotLocationQuery {
            print("NOT accepting region manager update as one shot location service is active")
            return
        }

        guard let last = locations.last else {
            print("Does not have a location")
            return
        }

        guard last.horizontalAccuracy <= 200 else {
            let inaccurateLocationMessage = "Ignoring location with accuracy over threshold." +
            "Accuracy: \(last.horizontalAccuracy)m"
            print(inaccurateLocationMessage)
            Current.clientEventStore.addEvent(ClientEvent(text: inaccurateLocationMessage,
                                                          type: .locationUpdate))
            return
        }

        let locationAge = Current.date().timeIntervalSince(last.timestamp)
        if locationAge > kLocationMaximumAge {
            print("Location is older than threshold.")
            return
        }

        api.submitLocation(updateType: .SignificantLocationUpdate, location: last,
                           zone: nil).catch { print("Error submitting location: \($0)" )}

        self.lastLocation = last
        self.lastLocationDate = Current.date()
//        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clErr = error as? CLError {
            let realm = Current.realm()
            // swiftlint:disable:next force_try
            try! realm.write {
                let locErr = LocationError(err: clErr)
                realm.add(locErr)
            }

            print("Received CLError:", clErr.debugDescription)
            if clErr.code == CLError.locationUnknown {
                // locationUnknown just means that GPS may be taking an extra moment, so don't throw an error.
                return
            }
        } else {
            print("Received non-CLError when we only expected CLError:", error.localizedDescription)
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?,
                         withError error: Error) {
        let errorText = "Region monitoring failed for region: \(region?.identifier ?? "Unknown"). "
        + "Error: \(error.localizedDescription)"
        let event = ClientEvent(text: errorText, type: .locationUpdate)
        Current.clientEventStore.addEvent(event)
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        guard let zone = zones.zoneForRegion(region) else {
            return
        }

        print("Started monitoring region", region.identifier, zone)
        locationManager.requestState(for: region)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState,
                         for region: CLRegion) {
        print("\(state.description) region", region.identifier)
        guard state != .unknown else {
            return
        }

        var trigger: LocationUpdateTrigger = .Unknown
        switch state {
        case .inside:
            trigger = .RegionEnter
        case .outside:
            trigger = .RegionExit
        case .unknown:
            assertionFailure("Should not get to unknown here")
        }

        self.triggerRegionEvent(manager, trigger: trigger, region: region)
    }
}

extension Array where Element == RLMZone {
    func zoneForRegion(_ region: CLRegion) -> RLMZone? {
        let filter: (RLMZone) -> Bool = { zone in
            return region.identifier == zone.ID
        }

        return self.filter(filter).first
    }
}

// MARK: BackgroundTask
extension RegionManager {
    func endBackgroundTaskWithName(_ name: String) {
        guard let task = self.backgroundTasks[name] else {
            return
        }

        if task != UIBackgroundTaskInvalid {
            Current.clientEventStore.addEvent(ClientEvent(text: "EndBackgroundTask: \(name)",
                type: .locationUpdate))
            UIApplication.shared.endBackgroundTask(task)
        }

        self.backgroundTasks.removeValue(forKey: name)
    }
}

extension CLRegionState {
    var description: String {
        switch self {
        case .inside:
            return "Inside"
        case .outside:
            return "Outside"
        default:
            return "Unknown"
        }
    }
}

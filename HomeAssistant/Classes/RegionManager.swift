//
//  RegionManager.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 8/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import CoreLocation
import Foundation
import Shared
import PromiseKit
import os
import UIKit
import UserNotifications

private let kLocationMaximumAge: TimeInterval = 10.0

class RegionManager: NSObject {
    let locationManager = CLLocationManager()
    var backgroundTask: UIBackgroundTaskIdentifier?
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

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func triggerRegionEvent(_ manager: CLLocationManager, trigger: LocationUpdateTrigger, region: CLRegion) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            let message = "Region update failed because client is not authenticated."
            Current.clientEventStore.addEvent(ClientEvent(text: message, type: .locationUpdate))
            return
        }

        self.lastLocationDate = Current.date()
        var trig = trigger
        guard let zone = zones.zoneForRegion(region) else {
            Current.Log.warning("Zone ID \(region.identifier) doesn't exist in Realm, syncing monitored regions now")
            syncMonitoredRegions()
            return
        }

        // Do nothing in case we don't want to trigger an enter event
        if zone.TrackingEnabled == false { Current.Log.verbose("Tracking not enabled for \(zone.ID)"); return }

        // If current SSID is in the filter list stop processing region event. This is to cut down on false exits.
        // https://github.com/home-assistant/home-assistant-iOS/issues/32
        if let currentSSID = ConnectionInfo.CurrentWiFiSSID, zone.SSIDFilter.contains(currentSSID) {
            let inaccurateLocationMessage = "Ignoring region event due to current SSID being in zone SSID filter"
            Current.clientEventStore.addEvent(ClientEvent(text: inaccurateLocationMessage, type: .locationUpdate))
            return
        }

        if region is CLBeaconRegion {
            if trigger == .RegionEnter { trig = .BeaconRegionEnter }
            if trigger == .RegionExit { trig = .BeaconRegionExit }
        } else {
            if trigger == .RegionEnter { trig = .GPSRegionEnter }
            if trigger == .RegionExit { trig = .GPSRegionExit }
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
            Current.clientEventStore.addEvent(ClientEvent(text: noChangeMessage, type: .locationUpdate))
            self.endBackgroundTaskWithName(taskName)
            return
        }

        // swiftlint:disable:next force_try
        try! zone.realm?.write {
            zone.inRegion = inRegion
        }

        guard trig != .BeaconRegionExit else {
            let noChangeMessage = "Not updating \(zone.debugDescription) because iBeacon exits are ignored"
            Current.clientEventStore.addEvent(ClientEvent(text: noChangeMessage, type: .locationUpdate))
            self.endBackgroundTaskWithName(taskName)
            return
        }

        let message = "Submitting location for zone \(zone.ID) with trigger \(trig.rawValue)."
        Current.clientEventStore.addEvent(ClientEvent(text: message, type: .locationUpdate))

        firstly { () -> Promise<Void> in
            if Current.settingsStore.useNewOneShotLocation {
                return api.GetAndSendLocation(trigger: trig, zone: zone).done { _ in
                    let message = "Succeeded updating zone \(zone.ID) with trigger \(trig.rawValue) using one-shot."
                    Current.clientEventStore.addEvent(ClientEvent(text: message, type: .locationUpdate))
                }
            } else {
                return api.SubmitLocation(
                    updateType: trig,
                    location: self.locationManager.location,
                    zone: zone
                ).done { _ in
                    let message = "Succeeded updating zone \(zone.ID) with trigger \(trig.rawValue)."
                    Current.clientEventStore.addEvent(ClientEvent(text: message, type: .locationUpdate))
                }
            }
        }.ensure {
            self.endBackgroundTaskWithName(taskName)
        }.catch { error in
            let eventName = trigger == .RegionEnter ? "Enter" : "Exit"
            let SSID = "SSID: \(ConnectionInfo.CurrentWiFiSSID ?? "Unavailable")"
            let event = ClientEvent(text: "Failed to send location after region \(eventName). SSID: \(SSID)",
                type: .locationUpdate)
            Current.clientEventStore.addEvent(event)
            Current.Log.error("Error sending location after region trigger event: \(error)")

            self.notifyOnError(trigger, error)
        }
    }

    func startMonitoring(zone: RLMZone) {
        if let beaconRegion = zone.beaconRegion {
            locationManager.startMonitoring(for: beaconRegion)
        }
        locationManager.startMonitoring(for: zone.circularRegion())
    }

    @objc func syncMonitoredRegions() {
        var unmonitoredZones = Set(self.zones)
        locationManager.monitoredRegions.forEach { [weak self] region in
            let removeZone = {
                let event = ClientEvent(text: "Stopping monitoring of region \(region.identifier)",
                    type: .locationUpdate)
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
            Current.Log.verbose("Starting monitoring of zone \(zone)")
            let event = ClientEvent(text: "Monitoring: \(zone.debugDescription)", type: .unknown)
            Current.clientEventStore.addEvent(event)
            self?.startMonitoring(zone: zone)
        }
    }

    func checkIfInsideAnyRegions(location: CLLocationCoordinate2D) -> Set<CLRegion> {
        return self.locationManager.monitoredRegions.filter { (region) -> Bool in
            if let circRegion = region as? CLCircularRegion {
                // Current.Log.verbose("Checking", circRegion.identifier)
                return circRegion.contains(location)
            }
            return false
        }
    }

    func notifyOnError(_ trigger: LocationUpdateTrigger, _ error: Error) {
        Current.Log.error("Error when sending location update triggered by \(trigger.rawValue): \(error)")
        /* let content = UNMutableNotificationContent()
        content.title = L10n.LocationUpdateErrorNotification.title(trigger.rawValue)
        content.body = error.localizedDescription
        content.sound = .default

        let notificationRequest = UNNotificationRequest(identifier: "error_updating_location", content: content,
                                                        trigger: nil)
        UNUserNotificationCenter.current().add(notificationRequest) */
    }
}

// MARK: CLLocationManagerDelegate

extension RegionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Current.Log.verbose("didVisit \(visit)")
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            return
        }

        // Only process visit entrances (ignoring departures) that are recent enough.
        guard visit.departureDate == Date.distantFuture,
            abs(visit.arrivalDate.timeIntervalSinceNow) < kLocationMaximumAge else {
            Current.Log.warning("Ignoring stale visit")
            return
        }

        let location = CLLocation(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)
        api.SubmitLocation(updateType: .Visit, location: location, zone: nil).catch { error in
            Current.Log.error("Error submitting location: \(error)")
            self.notifyOnError(.Visit, error)
        }
        self.lastLocationDate = Current.date()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Current.Log.verbose("didUpdateLocations \(locations)")
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            return
        }

        if Current.isPerformingSingleShotLocationQuery {
            Current.Log.warning("NOT accepting region manager update as one shot location service is active")
            return
        }

        guard let last = locations.last else {
            Current.Log.warning("Does not have a location")
            return
        }

        guard last.horizontalAccuracy <= 200 else {
            let inaccurateLocationMessage = "Ignoring location with accuracy over threshold." +
            "Accuracy: \(last.horizontalAccuracy)m"
            Current.clientEventStore.addEvent(ClientEvent(text: inaccurateLocationMessage,
                                                          type: .locationUpdate))
            return
        }

        let locationAge = Current.date().timeIntervalSince(last.timestamp)
        if locationAge > kLocationMaximumAge {
            Current.Log.warning("Location is older than threshold.")
            return
        }

        api.SubmitLocation(updateType: .SignificantLocationUpdate, location: last, zone: nil).catch { error in
            Current.Log.error("Error submitting location: \(error)")
            self.notifyOnError(.SignificantLocationUpdate, error)
        }

        self.lastLocation = last
        self.lastLocationDate = Current.date()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Current.Log.error("didFailWithError \(error)")
        if let clErr = error as? CLError {
            let realm = Current.realm()
            // swiftlint:disable:next force_try
            try! realm.write {
                let locErr = LocationError(err: clErr)
                realm.add(locErr)
            }

            Current.Log.warning("Received CLError: \(clErr)")
            if clErr.code == CLError.locationUnknown {
                // locationUnknown just means that GPS may be taking an extra moment, so don't throw an error.
                return
            }
        } else {
            Current.Log.error("Received non-CLError when we only expected CLError: \(error)")
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?,
                         withError error: Error) {
        let errorText = "Region monitoring failed for region: \(region?.identifier ?? "Unknown"). "
        + "Error: \(error.localizedDescription)"
        let event = ClientEvent(text: errorText, type: .locationUpdate)
        Current.clientEventStore.addEvent(event)
        Current.Log.error("Region monitoring failed: error: \(error), region: \(region.debugDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        Current.Log.verbose("didStartMonitoringFor \(region)")
        guard let zone = zones.zoneForRegion(region) else {
            return
        }

        Current.Log.verbose("Started monitoring region: \(region), zone: \(zone)")
        locationManager.requestState(for: region)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState,
                         for region: CLRegion) {
        Current.Log.verbose("didDetermineState \(state.description) region: \(region)")
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

        if task != UIBackgroundTaskIdentifier.invalid {
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

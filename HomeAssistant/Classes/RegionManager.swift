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
import UIKit

private let kLocationMaximumAge: TimeInterval = 10.0

class RegionManager: NSObject {

    let locationManager = CLLocationManager()
    var backgroundTask: UIBackgroundTaskIdentifier?
    let activityManager = CMMotionActivityManager()
    var lastActivity: CMMotionActivity?
    var lastLocation: CLLocation?
    var oneShotLocationActive: Bool = false

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

    func triggerRegionEvent(_ manager: CLLocationManager, trigger: LocationUpdateTrigger,
                            region: CLRegion) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            let message = "Region update failed because client is not authenticated."
            Current.clientEventStore.addEvent(ClientEvent(text: message, type: .locationUpdate))
            return
        }

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
                let message = "Not sending update for beacon region exit. On Purpose."
                Current.clientEventStore.addEvent(ClientEvent(text: message, type: .locationUpdate))
                return
            }
        } else {
            if trigger == .RegionEnter {
                trig = .GPSRegionEnter
            }
            if trigger == .RegionExit {
                trig = .GPSRegionExit
            }
        }

        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }

        let inRegion = (trigger == .RegionEnter)
        guard zone.inRegion != inRegion else {
            return
        }

        let message = "Submitting location for zone \(zone.ID) with trigger \(trig.rawValue)."
        Current.clientEventStore.addEvent(ClientEvent(text: message, type: .locationUpdate))
        api.submitLocation(updateType: trig, location: nil, zone: zone).done {
            // swiftlint:disable:next force_try
            try! zone.realm?.write {
                zone.inRegion = inRegion
            }

            let message = "Succeeded updating zone \(zone.ID) with trigger \(trig.rawValue)."
            Current.clientEventStore.addEvent(ClientEvent(text: message, type: .locationUpdate))

        }.ensure {
            self.endBackgroundTask()
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
        locationManager.startMonitoring(for: zone.circularRegion())

        if let beaconRegion = zone.beaconRegion {
            locationManager.startMonitoring(for: beaconRegion)
        }

        if Current.settingsStore.motionEnabled {
            activityManager.startActivityUpdates(to: coreMotionQueue) { [weak self] activity in
                self?.lastActivity = activity
            }
        }
    }

    @objc func syncMonitoredRegions() {
        // stop monitoring for all regions        
        locationManager.monitoredRegions.forEach { [weak self] region in
            let event = ClientEvent(text: "Stopping monitoring of region \(region.identifier)", type: .locationUpdate)
            Current.clientEventStore.addEvent(event)
            self?.locationManager.stopMonitoring(for: region)
        }

        // start monitoring for all existing regions
        zones.forEach { [weak self] zone in
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

        if let lastLocation = self.lastLocation, visit.departureDate < lastLocation.timestamp {
            return
        }

        let location = CLLocation(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)
        api.submitLocation(updateType: .Visit, location: location,
                           zone: nil).catch { print("Error submitting location: \($0)" )}
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

        let locationAge = Current.date().timeIntervalSince(last.timestamp)
        if locationAge > kLocationMaximumAge {
            print("Location is older than threshhold. ")
            return
        }

        print("RegionManager: Got location, stopping updates!", last.debugDescription, locations.count)
        api.submitLocation(updateType: .SignificantLocationUpdate, location: last,
                           zone: nil).catch { print("Error submitting location: \($0)" )}

        self.lastLocation = last

        locationManager.stopUpdatingLocation()
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

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
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
            return region.identifier == zone.beaconRegionID || region.identifier == zone.gpsRegionID
        }

        return self.filter(filter).first
    }
}

// MARK: BackgroundTask
extension RegionManager {
    func endBackgroundTask() {
        if backgroundTask! != UIBackgroundTaskIdentifier.invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask!)
            backgroundTask = UIBackgroundTaskIdentifier.invalid
        }
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

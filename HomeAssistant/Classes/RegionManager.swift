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
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.delegate = self
        locationManager.distanceFilter = kCLLocationAccuracyHundredMeters
        self.startMonitoring()
        self.syncMonitoredRegions()
    }

    private func startMonitoring() {
        locationManager.startMonitoringSignificantLocationChanges()
    }

    func triggerRegionEvent(_ manager: CLLocationManager, trigger: LocationUpdateTrigger,
                            region: CLRegion) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            return
        }

        var trig = trigger
        guard let zone = zones.filter({ region.identifier == $0.ID }).first else {
            print("Zone ID \(region.identifier) doesn't exist in Realm, syncing monitored regions now")
            syncMonitoredRegions()
            return
        }

        // Do nothing in case we don't want to trigger an enter event
        if zone.TrackingEnabled == false {
            print("Tracking enabled is false")
            return
        }

        if zone.IsBeaconRegion {
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

        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }

        let inRegion = (trig == .GPSRegionEnter || trig == .BeaconRegionEnter)
        guard zone.inRegion != inRegion else {
            return
        }

        let message = "Submitting location for zone \(zone.ID) with trigger \(trig.rawValue)."
        Current.clientEventStore.addEvent(ClientEvent(text: message, type: .locationUpdate))
        api.submitLocation(updateType: trig, location: nil, zone: zone).done {
            let realm = Current.realm()
            // swiftlint:disable:next force_try
            try! realm.write {
                zone.inRegion = inRegion
            }
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
        if let region = zone.region() {
            locationManager.startMonitoring(for: region)
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
            print("Stopping monitoring of region \(region.identifier)")
            self?.locationManager.stopMonitoring(for: region)
        }

        // start monitoring for all existing regions
        zones.forEach { [weak self] zone in
            print("Starting monitoring of zone \(zone)")
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

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            return
        }
        if Current.isPerformingSingleShotLocationQuery {
            print("NOT accepting region manager update as one shot location service is active")
            return
        }

        if self.lastLocation == nil {
            print("NOT accepting region manager update since we appear to be in startup and regions may not be active")
            return
        }

        print("RegionManager: Got location, stopping updates!", locations.last.debugDescription, locations.count)
        api.submitLocation(updateType: .SignificantLocationUpdate, location: locations.last,
                           zone: nil).catch { print("Error submitting location: \($0)" )}

        self.lastLocation = locations.last

        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Region entered", region.identifier)
        triggerRegionEvent(manager, trigger: .RegionEnter, region: region)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Region exited", region.identifier)
        triggerRegionEvent(manager, trigger: .RegionExit, region: region)
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

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        guard let zone = zones.filter({ region.identifier == $0.ID }).first else {
            return
        }

        print("Started monitoring region", region.identifier, zone)
        locationManager.requestState(for: region)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        var strState = "Unknown"
        if state == .inside {
            strState = "Inside"
        } else if state == .outside {
            strState = "Outside"
        } else if state == .unknown {
            strState = "Unknown"
        }
        print("\(strState) region", region.identifier)

        guard let zone = zones.filter({ region.identifier == $0.ID }).first else {
            return
        }

        let realm = Current.realm()
        // swiftlint:disable:next force_try
        try! realm.write {
            zone.inRegion = (state == .inside)
        }
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

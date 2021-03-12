import CoreLocation
import Foundation
import PromiseKit
import Shared

protocol ZoneManagerProcessorDelegate: AnyObject {
    func processor(_ processor: ZoneManagerProcessor, didLog state: ZoneManagerState)
}

protocol ZoneManagerProcessor: AnyObject {
    var delegate: ZoneManagerProcessorDelegate? { get set }

    func perform(event: ZoneManagerEvent) -> Promise<Void>
}

class ZoneManagerProcessorImpl: ZoneManagerProcessor {
    weak var delegate: ZoneManagerProcessorDelegate?

    func perform(event: ZoneManagerEvent) -> Promise<Void> {
        firstly {
            evaluate(event: event)
        }.tap { result in
            switch result {
            case .fulfilled:
                self.delegate?.processor(self, didLog: .didReceive(event))
            case let .rejected(error):
                self.delegate?.processor(self, didLog: .didIgnore(event, error))
            }
        }.then {
            Current.backgroundTask(withName: event.backgroundTaskDescription) { remaining in
                let trigger = event.asTrigger()
                return firstly { () -> Promise<CLLocation?> in
                    if event.shouldOneShotLocation {
                        return Current.location
                            .oneShotLocation(trigger.oneShotTimeout(maximum: remaining))
                            .map { $0 }
                    } else {
                        return .value(event.associatedLocation)
                    }
                }.map { location in
                    if let location = location {
                        return Self.sanitize(location: location, for: event)
                    } else {
                        return nil
                    }
                }.then { location in
                    Current.api.then(on: nil) { api in
                        api.SubmitLocation(
                            updateType: trigger,
                            location: location,
                            zone: event.associatedZone
                        )
                    }
                }
            }
        }
    }

    private static func ignore(_ error: ZoneManagerIgnoreReason) -> Promise<Void> {
        .init(error: error)
    }

    private func evaluate(event: ZoneManagerEvent) -> Promise<Void> {
        guard !Current.isPerformingSingleShotLocationQuery else {
            // never do any processing while actively pulling
            return Self.ignore(.duringOneShot)
        }

        switch event.eventType {
        case let .locationChange(locations):
            return Self.evaluateLocationChangeEvent(
                locations: locations
            )
        case let .region(region, state):
            return Self.evaluateRegionEvent(
                region: region,
                state: state,
                zone: event.associatedZone
            )
        }
    }

    private static func evaluateLocationChangeEvent(locations: [CLLocation]) -> Promise<Void> {
        if locations.isEmpty {
            return ignore(.locationMissingEntries)
        }

        if let lastLocation = locations.last,
           Current.date().timeIntervalSince(lastLocation.timestamp) > 30.0,
           Current.isCatalyst == false {
            // if we're just being tangentially told about locations because of creating the location manager,
            // we want to ignore it in favor if manually getting location in a non-this-class code path
            // on Catalyst we allow this to trigger a location change because region monitoring is largely unreliable
            return ignore(.locationUpdateTooOld)
        }

        return .value(())
    }

    private static func evaluateRegionEvent(region: CLRegion, state: CLRegionState, zone: RLMZone?) -> Promise<Void> {
        guard state != .unknown else {
            return ignore(.unknownRegionState)
        }

        guard let zone = zone else {
            return ignore(.unknownRegion)
        }

        guard zone.TrackingEnabled else {
            // Do nothing in case we don't want to trigger an enter event
            return ignore(.zoneDisabled)
        }

        if let current = Current.connectivity.currentWiFiSSID(), zone.SSIDFilter.contains(current) {
            // If current SSID is in the filter list stop processing region event.
            // This is to cut down on false exits.
            // https://github.com/home-assistant/home-assistant-iOS/issues/32
            return ignore(.ignoredSSID(current))
        }

        do {
            try zone.realm?.reentrantWrite {
                zone.inRegion = state == .inside
            }
        } catch {
            return ignore(.zoneUpdateFailed(error as NSError))
        }

        if region is CLBeaconRegion, state == .outside {
            return ignore(.beaconExitIgnored)
        }

        return .value(())
    }

    private static func sanitize(location: CLLocation, for event: ZoneManagerEvent) -> CLLocation {
        var fuzzedAccuracy: CLLocationDistance = 0

        // if we're getting a region monitoring event saying that we're inside, but we're not from GPS perspective
        if case let .region(region as CLCircularRegion, .inside) = event.eventType,
           !region.containsWithAccuracy(location) {
            fuzzedAccuracy += region.distanceWithAccuracy(from: location)
        }

        // if we're inside the overlap of the zone's monitored regions, but not in the zone
        if let zone = event.associatedZone,
           // convenience so we reuse the region
           case let zoneRegion = zone.circularRegion,
           // all of which contain this location
           zone.circularRegionsForMonitoring.allSatisfy({ $0.containsWithAccuracy(location) }),
           // but the zone doesn't
           !zoneRegion.containsWithAccuracy(location) {
            // from https://github.com/home-assistant/iOS/issues/1520
            fuzzedAccuracy += zoneRegion.distanceWithAccuracy(from: location)
        }

        guard fuzzedAccuracy > 0 else {
            return location
        }

        if #available(iOS 13.4, *) {
            return CLLocation(
                coordinate: location.coordinate,
                altitude: location.altitude,
                horizontalAccuracy: location.horizontalAccuracy + fuzzedAccuracy + 1.0,
                verticalAccuracy: location.verticalAccuracy,
                course: location.course,
                courseAccuracy: location.courseAccuracy,
                speed: location.speed,
                speedAccuracy: location.speedAccuracy,
                timestamp: location.timestamp
            )
        } else {
            return CLLocation(
                coordinate: location.coordinate,
                altitude: location.altitude,
                horizontalAccuracy: location.horizontalAccuracy + fuzzedAccuracy + 1.0,
                verticalAccuracy: location.verticalAccuracy,
                course: location.course,
                speed: location.speed,
                timestamp: location.timestamp
            )
        }
    }
}

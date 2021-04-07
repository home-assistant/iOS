import CoreLocation
import Foundation

protocol ZoneManagerAccuracyFuzzer {
    func additionalAccuracy(
        for location: CLLocation,
        for event: ZoneManagerEvent
    ) -> CLLocationDistance?
}

/// if we're getting a region monitoring event saying that we're inside, but we're not from GPS perspective
struct ZoneManagerAccuracyFuzzerRegionEnter: ZoneManagerAccuracyFuzzer {
    func additionalAccuracy(for location: CLLocation, for event: ZoneManagerEvent) -> CLLocationDistance? {
        guard case let .region(region as CLCircularRegion, .inside) = event.eventType,
           !region.containsWithAccuracy(location) else {
            return nil
        }

        return region.distanceWithAccuracy(from: location)
    }
}

/// if we're inside the overlap of the zone's monitored regions, but not in the zone
struct ZoneManagerAccuracyFuzzerMultiRegionOverlap: ZoneManagerAccuracyFuzzer {
    func additionalAccuracy(for location: CLLocation, for event: ZoneManagerEvent) -> CLLocationDistance? {
        guard let zone = event.associatedZone else {
            return nil
        }

        let zoneRegion = zone.circularRegion

        guard zone.circularRegionsForMonitoring.allSatisfy({ $0.containsWithAccuracy(location) }) else {
            // all of the regions think we're in the zone
            return nil
        }

        guard !zoneRegion.containsWithAccuracy(location) else {
           // but the zone doesn't
            return nil
        }

        // from https://github.com/home-assistant/iOS/issues/1520
        return zoneRegion.distanceWithAccuracy(from: location)
    }
}

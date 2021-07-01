import CoreLocation
import Foundation
import Shared

enum ZoneManagerAccuracyFuzzerChange {
    // adjust the accuracy value, without adjusting the coordiante's location
    case accuracy(CLLocationDistance)
    // do your best to avoid using this one. changing the location itself is 'lying' but sometimes necessary.
    case coordinate(CLLocationCoordinate2D)
}

protocol ZoneManagerAccuracyFuzzer {
    func fuzz(
        for location: CLLocation,
        for event: ZoneManagerEvent
    ) -> ZoneManagerAccuracyFuzzerChange?
}

extension Sequence where Element == ZoneManagerAccuracyFuzzer {
    func fuzz(location originalLocation: CLLocation, for event: ZoneManagerEvent) -> CLLocation {
        reduce(originalLocation) { location, fuzzer in
            if let change = fuzzer.fuzz(for: location, for: event) {
                Current.Log.info("fuzzing from \(fuzzer) with \(change)")

                switch change {
                case let .accuracy(additional):
                    return location.fuzzingAccuracy(by: additional)
                case let .coordinate(coordinate):
                    return location.changingCoordinate(to: coordinate)
                }
            } else {
                return location
            }
        }
    }
}

/// if we're getting a region monitoring event saying that we're inside, but we're not from GPS perspective
struct ZoneManagerAccuracyFuzzerRegionEnter: ZoneManagerAccuracyFuzzer {
    func fuzz(for location: CLLocation, for event: ZoneManagerEvent) -> ZoneManagerAccuracyFuzzerChange? {
        guard case let .region(region as CLCircularRegion, .inside) = event.eventType,
              !region.containsWithAccuracy(location) else {
            return nil
        }

        return .accuracy(region.distanceWithAccuracy(from: location))
    }
}

/// if we're inside the overlap of the zone's monitored regions, but not in the zone
struct ZoneManagerAccuracyFuzzerMultiRegionOverlap: ZoneManagerAccuracyFuzzer {
    func fuzz(for location: CLLocation, for event: ZoneManagerEvent) -> ZoneManagerAccuracyFuzzerChange? {
        guard let zone = event.associatedZone, case .region(_, .inside) = event.eventType else {
            return nil
        }

        let zoneRegion = zone.circularRegion

        guard zone.containsInRegions(location) else {
            // all of the regions think we're in the zone
            return nil
        }

        guard !zoneRegion.containsWithAccuracy(location) else {
            // but the zone doesn't
            return nil
        }

        // from https://github.com/home-assistant/iOS/issues/1520
        return .accuracy(zoneRegion.distanceWithAccuracy(from: location))
    }
}

/// if we're entering a zone that's contained within another zone, the gps coordinates may need shifting
/// because core requires gps inside if this overlap occurs - https://github.com/home-assistant/iOS/issues/1627
struct ZoneManagerAccuracyFuzzerMultiZone: ZoneManagerAccuracyFuzzer {
    func fuzz(for location: CLLocation, for event: ZoneManagerEvent) -> ZoneManagerAccuracyFuzzerChange? {
        guard let zone = event.associatedZone, case .region(_, .inside) = event.eventType else {
            return nil
        }

        guard zone.containsInRegions(location) else {
            // the zone needs to believe this location _should_ belong inside it, otherwise moving the coordinate is
            // an incorrect change. this can happen for e.g. entering one of the circular regions for <100m zone.
            return nil
        }

        let coordinate = location.coordinate
        let distance = zone.location.distance(from: location) - zone.Radius

        guard !zone.circularRegion.contains(coordinate), distance > 0 else {
            // this fuzzing is only necessary if the region doesn't contain without accuracy
            // this matches the core behavior of this edge case
            return nil
        }

        let containedZones = Current.realm()
            .objects(RLMZone.self)
            .filter {
                // ignoring accuracy because that is not what matters for this case
                // allowing the zone we're entering since we know we're not in it but we should be
                $0.circularRegion.contains(coordinate) || $0 == zone
            }

        guard containedZones.count > 1 else {
            // no overlapping zones for this location, no change is necessary
            return nil
        }

        let movedCoordinate = coordinate.moving(
            distance: .init(value: distance + 1.0, unit: .meters),
            direction: coordinate.bearing(to: zone.center)
        )

        return .coordinate(movedCoordinate)
    }
}

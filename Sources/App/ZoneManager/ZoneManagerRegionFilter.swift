import CoreLocation
import Foundation
import Shared

protocol ZoneManagerRegionFilter {
    func regions(
        from zones: AnyCollection<RLMZone>,
        currentRegions: AnyCollection<CLRegion>,
        lastLocation: CLLocation?
    ) -> AnyCollection<CLRegion>
}

class ZoneManagerRegionFilterImpl: ZoneManagerRegionFilter {
    struct Counts: Comparable {
        var beacon: Int
        var circular: Int

        static func < (lhs: Counts, rhs: Counts) -> Bool {
            lhs.beacon < rhs.beacon && lhs.circular < rhs.circular
        }

        init(beacon: Int, circular: Int) {
            self.beacon = beacon
            self.circular = circular
        }

        init<T: Sequence>(_ sequence: T) where T.Element == CLRegion {
            let counts = sequence.reduce(into: (beacon: 0, circular: 0)) { counts, region in
                if region is CLCircularRegion {
                    counts.circular += 1
                } else if region is CLBeaconRegion {
                    counts.beacon += 1
                } else {
                    // what is it like in the future?
                    Current.Log.error("unknown region type: \(type(of: region))")
                }
            }

            self.beacon = counts.beacon
            self.circular = counts.circular
        }

        func shouldReduce(option: Self, comparedTo limit: Self) -> Bool {
            if option.beacon > 0, limit.beacon < beacon {
                return true
            }

            if option.circular > 0, limit.circular < circular {
                return true
            }

            return false
        }

        var eventPayload: [String: String] { [
            "beacon": String(beacon),
            "circular": String(circular),
        ] }
    }

    let limits: Counts

    init(limits: Counts = Counts(beacon: 20, circular: 20)) {
        self.limits = limits
    }

    func regions(
        from zones: AnyCollection<RLMZone>,
        currentRegions: AnyCollection<CLRegion>,
        lastLocation: CLLocation?
    ) -> AnyCollection<CLRegion> {
        var segmented = Dictionary(uniqueKeysWithValues: zones.map { ($0, $0.regionsForMonitoring) })

        let startRegions = segmented.values.flatMap({ $0 })
        let startCounts = Counts(startRegions)

        if startCounts < limits {
            // We're starting out with a small enough count
            return AnyCollection(startRegions)
        }

        let sourceLocation: CLLocation?
        let sourceDecision: String

        if let lastLocation = lastLocation {
            sourceLocation = lastLocation
            sourceDecision = "last_location"
        } else if let homeLocation = zones.first(where: \.isHome)?.location {
            sourceLocation = homeLocation
            sourceDecision = "home_location"
        } else {
            sourceLocation = nil
            sourceDecision = "radius_and_random"
        }

        // We've exceeded the limit, so we need to start reducing.
        // We aim to clip off the ones that are further away.
        let sorted = segmented.sorted { lhs, rhs in
            if let sourceLocation = sourceLocation {
                // We have a location to compare against, so do distance
                return lhs.key.location.distance(from: sourceLocation) < rhs.key.location.distance(from: sourceLocation)
            } else {
                // We have neither a location nor a home zone, so just like...strip the bigger ones?
                return lhs.key.Radius < rhs.key.Radius
            }
        }

        // just used for logging
        var strippedZones = [RLMZone]()

        for option in sorted.reversed() {
            let currentCount = Counts(segmented.values.flatMap { $0 })
            let optionCount = Counts(option.value)

            if currentCount.shouldReduce(option: optionCount, comparedTo: limits) {
                // We strip off entire zones at a time if they contain any region which exceeds the count.
                strippedZones.append(option.key)
                segmented[option.key] = nil
            }
        }

        let result = segmented.values.flatMap { $0 }

        if Set(result) != Set(currentRegions) {
            // Avoid logging if we aren't changing anything
            // Note that the equality here is roughly `lhs.identifier != rhs.identifier` due to CLRegion behavior
            // We're okay with not having deep equality here (since this is an advisory log) -- deep equality
            // happens in ZoneManager when it's deciding which zones to create
            logError(
                counts: startCounts,
                allZones: zones,
                strippedZones: AnyCollection(strippedZones),
                decisionSource: sourceDecision
            )
        }

        return AnyCollection(result)
    }

    private func logError(
        counts: Counts,
        allZones: AnyCollection<RLMZone>,
        strippedZones: AnyCollection<RLMZone>,
        decisionSource: String
    ) {
        Current.clientEventStore.addEvent(ClientEvent(
            text: "Exceeded maximum monitored regions",
            type: .locationUpdate, payload: [
                "counts": counts.eventPayload,
                "limits": limits.eventPayload,
                "total_zones": allZones.count,
                "stripped_zones": strippedZones.map(\.identifier),
                "stripped_decision": decisionSource,
            ]
        )).cauterize()
    }
}

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

private struct ZoneManagerProcessorQueue {
    private var queue: [(ZoneManagerEvent, Resolver<Void>)] = []

    mutating func add(event: ZoneManagerEvent) -> Promise<Void> {
        let (promise, resolver) = Promise<Void>.pending()
        queue.insert((event, resolver), at: 0)
        return promise
    }

    mutating func pop() -> (ZoneManagerEvent, Resolver<Void>)? {
        queue.popLast()
    }
}

class ZoneManagerProcessorImpl: ZoneManagerProcessor {
    weak var delegate: ZoneManagerProcessorDelegate?

    var accuracyFuzzers: [ZoneManagerAccuracyFuzzer] = [
        ZoneManagerAccuracyFuzzerMultiZone(),
        ZoneManagerAccuracyFuzzerRegionEnter(),
        ZoneManagerAccuracyFuzzerMultiRegionOverlap(),
    ]

    private var queue = ZoneManagerProcessorQueue()
    private var currentEvent: ZoneManagerEvent?
    private var lastUpdate: Date = .distantPast

    var onCompletedEvent: (() -> Void)?

    func perform(event: ZoneManagerEvent) -> Promise<Void> {
        let promise = queue.add(event: event)
        processNextEvent()
        return promise
    }

    private func processNextEvent() {
        guard currentEvent == nil else { return }
        guard let (event, resolver) = queue.pop() else { return }

        currentEvent = event

        firstly {
            evaluate(event: event)
        }.tap { result in
            switch result {
            case .fulfilled:
                self.delegate?.processor(self, didLog: .didReceive(event))
            case let .rejected(error):
                self.delegate?.processor(self, didLog: .didIgnore(event, error))
            }
        }.then { [accuracyFuzzers] in
            Current.backgroundTask(withName: event.backgroundTaskDescription) { remaining in
                let trigger = event.asTrigger()
                return firstly { () -> Promise<CLLocation?> in
                    if event.shouldOneShotLocation {
                        return Current.location.oneShotLocation(trigger, remaining)
                            .map { .some($0) }
                    } else {
                        return .value(event.associatedLocation)
                    }
                }.map { location in
                    if let location = location {
                        return accuracyFuzzers.fuzz(location: location, for: event)
                    } else {
                        return nil
                    }
                }.then { location in
                    when(fulfilled: Current.apis.map { api in
                        api.SubmitLocation(
                            updateType: trigger,
                            location: location,
                            zone: event.associatedZone
                        )
                    })
                }
            }
        }.tap { [self] result in
            if result.isFulfilled {
                // only considered an update if it happened
                lastUpdate = Current.date()
            }

            onCompletedEvent?()
            currentEvent = nil
            processNextEvent()
        }.pipe(
            to: resolver.resolve
        )
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
                locations: locations,
                lastUpdate: lastUpdate
            )
        case let .region(region, state):
            return Self.evaluateRegionEvent(
                region: region,
                state: state,
                zone: event.associatedZone
            )
        }
    }

    private static func evaluateLocationChangeEvent(locations: [CLLocation], lastUpdate: Date) -> Promise<Void> {
        if locations.isEmpty {
            return ignore(.locationMissingEntries)
        }

        if Current.date().timeIntervalSince(lastUpdate) < 30.0 {
            return ignore(.recentlyUpdated)
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
            // https://github.com/home-assistant/iOS/issues/32
            return ignore(.ignoredSSID(current))
        }

        zone.realm?.reentrantWrite {
            zone.inRegion = state == .inside
        }

        if region is CLBeaconRegion, state == .outside {
            return ignore(.beaconExitIgnored)
        }

        return .value(())
    }
}

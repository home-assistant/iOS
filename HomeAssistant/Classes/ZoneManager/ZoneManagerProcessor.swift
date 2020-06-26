import Foundation
import Shared
import PromiseKit

protocol ZoneManagerProcessorDelegate: AnyObject {
    func processor(_ processor: ZoneManagerProcessor, didLog state: ZoneManagerState)
}

protocol ZoneManagerProcessor: AnyObject {
    var delegate: ZoneManagerProcessorDelegate? { get set }

    func perform(event: ZoneManagerEvent) -> Promise<Void>
}

enum ZoneManagerProcessorPerformError: Error {
    case noAPI
}

class ZoneManagerProcessorImpl: ZoneManagerProcessor {
    weak var delegate: ZoneManagerProcessorDelegate?

    func perform(event: ZoneManagerEvent) -> Promise<Void> {
        guard let api = Current.api() else {
            return .init(error: ZoneManagerProcessorPerformError.noAPI)
        }

        return firstly {
            evaluate(event: event)
        }.tap { result in
            switch result {
            case .fulfilled:
                self.delegate?.processor(self, didLog: .didReceive(event))
            case .rejected(let error):
                self.delegate?.processor(self, didLog: .didIgnore(event, error))
            }
        }.then {
            UIApplication.shared.backgroundTask(withName: event.backgroundTaskDescription) { remaining in
                if event.shouldOneShotLocation {
                    return api.GetAndSendLocation(
                        trigger: event.asTrigger(),
                        zone: event.associatedZone,
                        maximumBackgroundTime: remaining
                    )
                } else {
                    return api.SubmitLocation(
                        updateType: event.asTrigger(),
                        location: event.associatedLocation,
                        zone: event.associatedZone
                    )
                }
            }
        }
    }

    private func evaluate(event: ZoneManagerEvent) -> Promise<Void> {
        func ignore(_ error: ZoneManagerIgnoreReason) -> Promise<Void> {
            return .init(error: error)
        }

        guard !Current.isPerformingSingleShotLocationQuery else {
            // never do any processing while actively pulling
            return ignore(.duringOneShot)
        }

        switch event.eventType {
        case .locationChange(let locations):
            if locations.isEmpty {
                return ignore(.locationMissingEntries)
            }
        case .region(_, let state):
            guard state != .unknown else {
                return ignore(.unknownRegionState)
            }

            guard let zone = event.associatedZone else {
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

            let inRegion = state == .inside
            guard zone.inRegion != inRegion else {
                return ignore(.zoneStateAgrees)
            }

            do {
                try zone.realm?.write {
                    zone.inRegion = inRegion
                }
            } catch {
                return ignore(.zoneUpdateFailed(error as NSError))
            }

            guard event.asTrigger() != .BeaconRegionExit else {
                return ignore(.beaconExitIgnored)
            }
        }

        return .value(())
    }
}

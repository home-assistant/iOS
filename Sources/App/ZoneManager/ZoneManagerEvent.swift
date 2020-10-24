import Foundation
import CoreLocation
import Shared

struct ZoneManagerEvent: Equatable, CustomStringConvertible {
    enum EventType: Equatable, CustomStringConvertible {
        case region(CLRegion, CLRegionState)
        case locationChange([CLLocation])

        var description: String {
            switch self {
            case .region(let region, let state):
                let readableState = { () -> String in
                    switch state {
                    case .inside:
                        return "inside"
                    case .outside:
                        return "outside"
                    case .unknown:
                        return "unknown"
                    }
                }()
                return "region(\(region), \(readableState))"
            case .locationChange(let locations):
                return "locationChange(\(locations))"
            }
        }
    }

    var eventType: EventType
    var associatedZone: RLMZone?

    internal init(
        eventType: ZoneManagerEvent.EventType,
        associatedZone: RLMZone? = nil
    ) {
        self.eventType = eventType
        self.associatedZone = associatedZone
    }

    static func == (lhs: ZoneManagerEvent, rhs: ZoneManagerEvent) -> Bool {
        return lhs.eventType == rhs.eventType &&
            lhs.associatedZone?.ID == rhs.associatedZone?.ID
    }

    var description: String {
        var attributes = [String]()

        attributes.append(String(describing: eventType))

        if let zone = associatedZone {
            if zone.isInvalidated {
                attributes.append("zone deleted")
            } else {
                attributes.append(zone.ID)
            }
        }

        return "ZoneManagerEvent(\(attributes.joined(separator: ", ")))"
    }

    var shouldOneShotLocation: Bool {
        switch eventType {
        case .region(let region, _) where region is CLBeaconRegion:
            return false
        default:
            return true
        }
    }

    var associatedLocation: CLLocation? {
        switch eventType {
        case .locationChange(let locations):
            return locations.last
        case .region:
            return nil
        }
    }

    var backgroundTaskDescription: String {
        "bg-loc-event-" + {
            switch eventType {
            case .locationChange:
                return "location-change"
            case .region(let region, _):
                return "region-\(region.identifier)"
            }
        }()
    }

    func asFirableEvent() -> (eventType: String, eventData: [String: Any])? {
        guard case .region(let region, let state) = eventType, let zone = associatedZone else {
            return nil
        }

        return HomeAssistantAPI.zoneStateEvent(region: region, state: state, zone: zone)
    }

    func asTrigger() -> LocationUpdateTrigger {
        switch eventType {
        case .region(let region, let state):
            let isBeacon = region is CLBeaconRegion

            switch state {
            case .inside:
                return isBeacon ? .BeaconRegionEnter : .GPSRegionEnter
            case .outside:
                return isBeacon ? .BeaconRegionExit : .GPSRegionExit
            case .unknown:
                return .Unknown
            }
        case .locationChange:
            return .SignificantLocationUpdate
        }
    }
}

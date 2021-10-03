import Foundation

enum ZoneManagerIgnoreReason: LocalizedError, Equatable {
    case duringOneShot
    case locationUpdateTooOld
    case locationMissingEntries
    case unknownRegionState
    case unknownRegion
    case zoneDisabled
    case ignoredSSID(String)
    case beaconExitIgnored
    case recentlyUpdated

    var errorDescription: String? {
        switch self {
        case .duringOneShot:
            return "ignoring during one shot"
        case .locationMissingEntries:
            return "location update missing evennts"
        case .locationUpdateTooOld:
            return "location update from the past"
        case .unknownRegionState:
            return "unknown region state"
        case .unknownRegion:
            return "unknown region id"
        case .zoneDisabled:
            return "zone has tracking disabled"
        case let .ignoredSSID(ssid):
            return "ignored due to ssid \(ssid)"
        case .beaconExitIgnored:
            return "beacon exit ignored"
        case .recentlyUpdated:
            return "recent location update already occurred"
        }
    }
}

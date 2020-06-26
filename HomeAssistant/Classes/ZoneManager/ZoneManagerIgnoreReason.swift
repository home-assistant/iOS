import Foundation

enum ZoneManagerIgnoreReason: LocalizedError, Equatable {
    case duringOneShot
    case locationMissingEntries
    case unknownRegionState
    case unknownRegion
    case zoneDisabled
    case zoneStateAgrees
    case ignoredSSID(String)
    case zoneUpdateFailed(NSError) // NSError so Equatable for laziness
    case beaconExitIgnored

    var errorDescription: String? {
        switch self {
        case .duringOneShot:
            return "ignoring during one shot"
        case .locationMissingEntries:
            return "location update missing evennts"
        case .unknownRegionState:
            return "unknown region state"
        case .unknownRegion:
            return "unknown region id"
        case .zoneDisabled:
            return "zone has tracking disabled"
        case .zoneStateAgrees:
            return "zone already in state"
        case .ignoredSSID(let ssid):
            return "ignored due to ssid \(ssid)"
        case .zoneUpdateFailed(let error):
            return "failed to update realm: \(error.localizedDescription)"
        case .beaconExitIgnored:
            return "beacon exit ignored"
        }
    }
}

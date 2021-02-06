import CoreLocation
import Foundation

/// Wraps CLRegion but does deep inspection of properties
/// so changing e.g. lat/long breaks Equatable rather than relying on identifier
struct ZoneManagerEquatableRegion: Hashable {
    let region: CLRegion

    private var beaconRegion: CLBeaconRegion? {
        region as? CLBeaconRegion
    }

    private var circularReason: CLCircularRegion? {
        region as? CLCircularRegion
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(region.hash)
    }

    static func == (lhs: ZoneManagerEquatableRegion, rhs: ZoneManagerEquatableRegion) -> Bool {
        guard lhs.region.identifier == rhs.region.identifier else {
            return false
        }

        if let lhs = lhs.beaconRegion, let rhs = rhs.beaconRegion {
            if #available(iOS 13, *) {
                return lhs.uuid == rhs.uuid &&
                    lhs.minor == rhs.minor &&
                    lhs.major == rhs.major
            } else {
                return lhs.proximityUUID == rhs.proximityUUID &&
                    lhs.minor == rhs.minor &&
                    lhs.major == rhs.major
            }
        } else if let lhs = lhs.circularReason, let rhs = rhs.circularReason {
            return lhs.center.latitude == rhs.center.latitude &&
                lhs.center.longitude == rhs.center.longitude &&
                lhs.radius == rhs.radius
        } else {
            return false
        }
    }
}

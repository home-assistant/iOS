import CoreLocation
import Foundation
import PromiseKit
import Shared

/// Determines whether the user is likely on a plane without requiring connectivity, by matching
/// known in-flight Wi-Fi SSIDs and, failing that, checking GPS ground speed and altitude.
enum FlightDetector {
    /// Ground speed no ground vehicle plausibly sustains (~430 km/h), safely above high-speed trains.
    private static let cruiseSpeed: CLLocationSpeed = 120
    /// Climb/descent combination: fast and high together, excluding driving at high altitude.
    private static let climbAltitude: CLLocationDistance = 4000
    private static let climbSpeed: CLLocationSpeed = 60
    private static let locationTimeout: TimeInterval = 5

    static func isLikelyFlying() async -> Bool {
        if let ssid = await Current.connectivity.currentWiFiSSID(), InFlightWiFiSSIDs.matches(ssid) {
            Current.Log.info("Flight detected via in-flight Wi-Fi SSID")
            return true
        }
        return await hasInFlightMotion()
    }

    private static func hasInFlightMotion() async -> Bool {
        let authorizationStatus = CLLocationManager().authorizationStatus
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            return false
        }

        let location: CLLocation? = await withCheckedContinuation { continuation in
            CLLocationManager.oneShotLocation(timeout: locationTimeout)
                .done { continuation.resume(returning: $0) }
                .catch { _ in continuation.resume(returning: nil) }
        }
        // No usable fix (common inside a fuselage away from a window) means "unknown", not "not flying".
        guard let location, location.speed >= 0 else { return false }

        if location.speed >= cruiseSpeed {
            Current.Log.info("Flight detected via ground speed \(location.speed) m/s")
            return true
        }
        if location.verticalAccuracy > 0, location.altitude >= climbAltitude, location.speed >= climbSpeed {
            Current.Log.info("Flight detected via altitude \(location.altitude)m at \(location.speed) m/s")
            return true
        }
        return false
    }
}

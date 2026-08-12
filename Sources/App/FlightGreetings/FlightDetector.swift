import CoreLocation
import Foundation
import Shared

/// Determines whether the user is likely on a plane without requiring connectivity, by matching
/// known in-flight Wi-Fi SSIDs, then cabin air pressure, and finally GPS ground speed and altitude.
enum FlightDetector {
    /// Ground speed no ground vehicle plausibly sustains (~430 km/h), safely above high-speed trains.
    private static let cruiseSpeed: CLLocationSpeed = 120
    /// Climb/descent combination: fast and high together, excluding driving at high altitude.
    private static let climbAltitude: CLLocationDistance = 4000
    private static let climbSpeed: CLLocationSpeed = 60
    /// A device with a working network isn't on a plane whose Wi-Fi we failed to recognize, so a
    /// warm fix is all it can offer and there is no reason to spend more.
    private static let onlineLocationTimeout: TimeInterval = 5
    /// Being offline is itself weak evidence of a flight, and it's also what makes a fix slow: with
    /// no network there is no assistance data, so a cold GPS start runs to tens of seconds.
    private static let offlineLocationTimeout: TimeInterval = 45

    static func isLikelyFlying() async -> Bool {
        if let ssid = await Current.connectivity.currentWiFiSSID(), InFlightWiFiSSIDs.matches(ssid) {
            Current.Log.info("Flight detected via in-flight Wi-Fi SSID")
            return true
        }

        if cabinPressureIndicatesFlight {
            return true
        }

        let timeout = isOffline ? offlineLocationTimeout : onlineLocationTimeout
        return await hasInFlightMotion(timeout: timeout)
    }

    /// Whether the barometer currently reads like a pressurized cabin.
    ///
    /// Gated on being offline, which is what keeps the low-pressure rule honest: high ground with bad
    /// weather can reach cabin cruise pressure, but a device sitting there has a network. A plane
    /// that does have Wi-Fi is caught by its SSID before this is consulted.
    static var cabinPressureIndicatesFlight: Bool {
        guard isOffline else { return false }
        let evidence = CabinPressureMonitor.shared.evidence
        guard evidence.indicatesFlight else { return false }
        Current.Log.info("Flight detected via cabin pressure: \(evidence)")
        return true
    }

    private static var isOffline: Bool {
        Current.connectivity.simpleNetworkType() == .noConnection
    }

    private static func hasInFlightMotion(timeout: TimeInterval) async -> Bool {
        let authorizationStatus = CLLocationManager().authorizationStatus
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            return false
        }

        // No usable fix (common inside a fuselage away from a window) means "unknown", not "not
        // flying"; the pressure signal above is what covers that case.
        guard let location = await FlightSpeedProbe.firstFixWithSpeed(timeout: timeout) else {
            return false
        }

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

#if os(macOS)
import CoreLocation

public extension CLAuthorizationStatus {
    /// Core Location marks "when in use" unavailable on macOS, where an app is either authorized or not.
    /// The location code is shared with iOS and names this case throughout, so it exists here as a status
    /// the system never reports, which leaves every comparison against it false.
    static var authorizedWhenInUse: CLAuthorizationStatus {
        CLAuthorizationStatus(rawValue: 4) ?? .authorizedAlways
    }
}
#endif

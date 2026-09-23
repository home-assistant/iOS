import CoreLocation
import Foundation

/// Which signal decided the server the "Closest Server" row names — the same two signals, in the
/// same priority, that `LocationBasedServerSwitcher` switches on.
///
/// The row shows a server either way, so without this the reason behind it is invisible: a server
/// matched by its Wi-Fi network is one the user is definitely at, while one matched by distance is
/// merely the nearest home and may be nowhere near.
enum ServerProximitySource: Equatable {
    /// This device is on one of the server's internal-URL Wi-Fi networks. Being on the network is
    /// being at that home, so no distance is involved.
    case homeNetwork
    /// No home network matched, so the server won on how far this device is from its `zone.home`.
    case location(distance: CLLocationDistance)
}

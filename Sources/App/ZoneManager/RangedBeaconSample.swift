import CoreLocation

struct RangedBeaconSample: Equatable {
    let proximity: CLProximity
    let rssi: Int
}

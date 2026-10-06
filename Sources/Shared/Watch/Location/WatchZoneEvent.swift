import Foundation

/// The watch crossing the edge of one of a server's zones, as its zone monitoring saw it.
public struct WatchZoneEvent: Equatable {
    public let zone: AppZone
    public let entered: Bool

    public init(zone: AppZone, entered: Bool) {
        self.zone = zone
        self.entered = entered
    }

    var locationTrigger: LocationUpdateTrigger {
        entered ? .GPSRegionEnter : .GPSRegionExit
    }
}

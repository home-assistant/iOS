import CoreLocation
import Foundation

public extension WebhookUpdateLocation {
    /// The `update_location` payload a server receives under its location privacy setting.
    ///
    /// Shared by the iPhone and the Apple Watch, which each report their own location as separate
    /// devices but must honour the same three choices: the exact fix, only the zones the fix falls
    /// in, or nothing beyond the battery level.
    ///
    /// - Parameters:
    ///   - zone: the zone the trigger is about (a region entered or exited), if any.
    ///   - supportsInZones: whether the server accepts `in_zones` on location updates.
    ///   - zonesContaining: the server's tracked zones a location falls in, smallest first.
    init(
        privacy: ServerLocationPrivacy,
        trigger: LocationUpdateTrigger,
        location: CLLocation?,
        zone: AppZone?,
        supportsInZones: Bool,
        currentSSID: String?,
        zonesContaining: (CLLocation) -> [AppZone]
    ) {
        switch privacy {
        case .exact:
            self.init(trigger: trigger, location: location, zone: zone, currentSSID: currentSSID)
        case .zoneOnly:
            guard trigger == .BeaconRegionEnter || location != nil else {
                self.init(trigger: trigger)
                return
            }
            let inZones = Self.zones(
                for: trigger,
                location: location,
                fallbackZone: zone,
                zonesContaining: zonesContaining
            )
            self.init(
                trigger: trigger,
                usingNameOf: Self.locationNameZone(
                    for: trigger,
                    from: inZones,
                    fallbackZone: zone,
                    supportsInZones: supportsInZones
                ),
                inZones: supportsInZones ? inZones : nil
            )
        case .never:
            self.init(trigger: trigger)
        }
    }

    private static func zones(
        for trigger: LocationUpdateTrigger,
        location: CLLocation?,
        fallbackZone zone: AppZone?,
        zonesContaining: (CLLocation) -> [AppZone]
    ) -> [AppZone] {
        if trigger == .BeaconRegionEnter {
            return zone.flatMap { $0.trackingEnabled ? [$0] : nil } ?? []
        }
        return location.map(zonesContaining) ?? []
    }

    private static func locationNameZone(
        for trigger: LocationUpdateTrigger,
        from zones: [AppZone],
        fallbackZone zone: AppZone?,
        supportsInZones: Bool
    ) -> AppZone? {
        if supportsInZones {
            return zones.first { !$0.isPassive }
        } else if trigger == .BeaconRegionEnter {
            return zone
        } else {
            return zones.first
        }
    }
}

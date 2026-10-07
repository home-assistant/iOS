import CoreLocation
import Foundation
@testable import Shared
import Testing

// Serialized: the tests override the process-wide `Current.device.batteries`.
@Suite(.serialized)
struct WebhookUpdateLocationPrivacyTests {
    private let fix = CLLocation(
        coordinate: .init(latitude: 1.5, longitude: 2.5),
        altitude: 10,
        horizontalAccuracy: 5,
        verticalAccuracy: 3,
        timestamp: Date()
    )
    private let home = AppZone(entityId: "zone.home", serverIdentifier: "s", latitude: 1.5, longitude: 2.5, radius: 50)
    private let passive = AppZone(entityId: "zone.big", serverIdentifier: "s", radius: 5000, isPassive: true)

    init() {
        Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }
    }

    private func payload(
        _ privacy: ServerLocationPrivacy,
        trigger: LocationUpdateTrigger = .Manual,
        location: CLLocation?,
        zone: AppZone? = nil,
        supportsInZones: Bool = true,
        zonesContaining: [AppZone] = []
    ) -> [String: Any] {
        WebhookUpdateLocation(
            privacy: privacy,
            trigger: trigger,
            location: location,
            zone: zone,
            supportsInZones: supportsInZones,
            currentSSID: nil,
            zonesContaining: { _ in zonesContaining }
        ).toJSON()
    }

    @Test func exactSendsTheFix() {
        let json = payload(.exact, location: fix, zonesContaining: [home])

        #expect(json["gps"] as? [Double] == [1.5, 2.5])
        #expect(json["gps_accuracy"] as? Double == 5)
        #expect(json["location_name"] == nil)
        #expect(json["battery"] as? Int == 44)
    }

    @Test func zoneOnlySendsTheZoneAndNoCoordinates() {
        let json = payload(.zoneOnly, location: fix, zonesContaining: [home, passive])

        #expect(json["gps"] == nil)
        #expect(json["location_name"] as? String == "home")
        #expect(json["in_zones"] as? [String] == ["zone.home", "zone.big"])
    }

    @Test func zoneOnlyOutsideEveryZoneIsNotHome() {
        let json = payload(.zoneOnly, location: fix, zonesContaining: [])

        #expect(json["location_name"] as? String == LocationNames.NotHome.rawValue)
        #expect(json["in_zones"] as? [String] == [])
    }

    @Test func zoneOnlyLeavesOutInZonesForAnOlderServer() {
        let json = payload(.zoneOnly, location: fix, supportsInZones: false, zonesContaining: [passive, home])

        // Without `in_zones`, the first (smallest) zone names the location, passive or not.
        #expect(json["location_name"] as? String == "big")
        #expect(json["in_zones"] == nil)
    }

    @Test func zoneOnlyWithoutAFixSendsNoLocation() {
        let json = payload(.zoneOnly, trigger: .GPSRegionExit, location: nil, zone: home, zonesContaining: [home])

        #expect(json["gps"] == nil)
        #expect(json["location_name"] == nil)
        #expect(json["battery"] as? Int == 44)
    }

    @Test func neverSendsNoLocation() {
        let json = payload(.never, location: fix, zone: home, zonesContaining: [home])

        #expect(json["gps"] == nil)
        #expect(json["location_name"] == nil)
        #expect(json["in_zones"] == nil)
        #expect(json["battery"] as? Int == 44)
    }

    @Test func zoneOnlyNamesTheBeaconZoneEnteredWithoutAFix() {
        let json = payload(.zoneOnly, trigger: .BeaconRegionEnter, location: nil, zone: home)

        #expect(json["location_name"] as? String == "home")
        #expect(json["in_zones"] as? [String] == ["zone.home"])
    }

    @Test func zoneOnlyNamesTheBeaconZoneForAnOlderServer() {
        let json = payload(.zoneOnly, trigger: .BeaconRegionEnter, location: nil, zone: home, supportsInZones: false)

        #expect(json["location_name"] as? String == "home")
        #expect(json["in_zones"] == nil)
    }

    @Test func zoneOnlyIgnoresABeaconZoneThatIsNotTracked() {
        var untracked = home
        untracked.trackingEnabled = false

        let json = payload(.zoneOnly, trigger: .BeaconRegionEnter, location: nil, zone: untracked)

        #expect(json["location_name"] as? String == LocationNames.NotHome.rawValue)
        #expect(json["in_zones"] as? [String] == [])
    }
}

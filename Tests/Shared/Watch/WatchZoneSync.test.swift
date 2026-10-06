import Foundation
@testable import Shared
import Testing

struct WatchZoneSyncTests {
    private let server = Server.fake()

    private func state(_ entityId: String, attributes: [String: Any]) -> [String: Any] {
        [
            "entity_id": entityId,
            "state": "0",
            "attributes": attributes,
            "last_changed": "2026-01-01T00:00:00+00:00",
            "last_updated": "2026-01-01T00:00:00+00:00",
            "context": ["id": "1", "parent_id": NSNull(), "user_id": NSNull()],
        ]
    }

    @Test func keepsOnlyTheZonesOfTheStates() throws {
        let json: [[String: Any]] = [
            state("zone.home", attributes: [
                "friendly_name": "Home",
                "latitude": 52.37,
                "longitude": 4.89,
                "radius": 100.0,
                "passive": false,
            ]),
            state("zone.work", attributes: [
                "friendly_name": "Work",
                "latitude": 52.1,
                "longitude": 5.1,
                "radius": 250.0,
                "passive": true,
                "track_ios": false,
            ]),
            state("light.kitchen", attributes: ["friendly_name": "Kitchen"]),
        ]

        let zones = WatchZoneSync.zones(fromRESTStates: json, server: server)
            .sorted { $0.entityId < $1.entityId }

        #expect(zones.map(\.entityId) == ["zone.home", "zone.work"])
        let home = try #require(zones.first)
        #expect(home.identifier == AppZone.primaryKey(
            sourceIdentifier: "zone.home",
            serverIdentifier: server.identifier.rawValue
        ))
        #expect(home.serverIdentifier == server.identifier.rawValue)
        #expect(home.latitude == 52.37)
        #expect(home.longitude == 4.89)
        #expect(home.radius == 100)
        #expect(home.trackingEnabled)
        #expect(!home.isPassive)

        let work = try #require(zones.last)
        #expect(work.isPassive)
        #expect(!work.trackingEnabled)
    }

    @Test func anUnexpectedBodyHasNoZones() {
        #expect(WatchZoneSync.zones(fromRESTStates: ["message": "nope"], server: server).isEmpty)
    }
}

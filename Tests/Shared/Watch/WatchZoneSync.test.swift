import Foundation
import GRDB
@testable import Shared
import Testing

/// Counts how often the fake transport was asked for the states.
private final class FetchCounter {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        value += 1
    }
}

// Serialized: the tests swap `Current.database` and share a defaults suite.
@Suite(.serialized)
final class WatchZoneSyncTests {
    private static let suiteName = "WatchZoneSyncTests"

    private let server = Server.fake()
    private let defaults: UserDefaults
    private let previousDatabase = Current.database

    init() throws {
        self.defaults = try #require(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)
        let database = try DatabaseQueue(path: ":memory:")
        try AppZoneTable().createIfNeeded(database: database)
        Current.database = { database }
    }

    deinit {
        Current.database = previousDatabase
    }

    private var homeState: [String: Any] {
        state("zone.home", attributes: [
            "friendly_name": "Home",
            "latitude": 52.37,
            "longitude": 4.89,
            "radius": 100.0,
            "passive": false,
        ])
    }

    private func storedZones(of server: Server) -> [AppZone] {
        AppZone.all().filter { $0.serverIdentifier == server.identifier.rawValue }
    }

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

    @Test func refreshStoresTheServersZones() async throws {
        let counter = FetchCounter()
        let home = homeState

        let changed = try await WatchZoneSync.refreshIfNeeded(server: server, defaults: defaults) { _, _ in
            counter.increment()
            return [home]
        }

        #expect(changed)
        #expect(counter.count == 1)
        #expect(storedZones(of: server).map(\.entityId) == ["zone.home"])
    }

    @Test func freshZonesAreNotFetchedAgainUnlessForced() async throws {
        let counter = FetchCounter()
        let home = homeState
        let fetch: WatchZoneSync.Fetch = { _, _ in
            counter.increment()
            return [home]
        }

        try await WatchZoneSync.refreshIfNeeded(server: server, defaults: defaults, fetch: fetch)
        let second = try await WatchZoneSync.refreshIfNeeded(server: server, defaults: defaults, fetch: fetch)
        #expect(!second)
        #expect(counter.count == 1)

        let forced = try await WatchZoneSync.refreshIfNeeded(
            server: server,
            force: true,
            defaults: defaults,
            fetch: fetch
        )
        // Fetched again, but the zones are the same ones.
        #expect(!forced)
        #expect(counter.count == 2)
    }

    @Test func replacingOneServersZonesLeavesTheOthersAlone() throws {
        let other = Server.fake()
        try WatchZoneSync.replaceZones(
            [AppZone(entityId: "zone.work", serverIdentifier: other.identifier.rawValue)],
            for: other.identifier
        )
        try WatchZoneSync.replaceZones(
            [AppZone(entityId: "zone.home", serverIdentifier: server.identifier.rawValue)],
            for: server.identifier
        )

        let changed = try WatchZoneSync.replaceZones(
            [AppZone(entityId: "zone.gym", serverIdentifier: server.identifier.rawValue)],
            for: server.identifier
        )

        #expect(changed)
        #expect(storedZones(of: server).map(\.entityId) == ["zone.gym"])
        #expect(storedZones(of: other).map(\.entityId) == ["zone.work"])
    }

    @Test func removingAServersZonesForgetsThemAndWhenTheyWereFetched() async throws {
        let counter = FetchCounter()
        let home = homeState
        let fetch: WatchZoneSync.Fetch = { _, _ in
            counter.increment()
            return [home]
        }
        try await WatchZoneSync.refreshIfNeeded(server: server, defaults: defaults, fetch: fetch)

        WatchZoneSync.removeZones(for: server.identifier, defaults: defaults)

        #expect(storedZones(of: server).isEmpty)
        // Opting in again fetches straight away rather than waiting out the old refresh.
        try await WatchZoneSync.refreshIfNeeded(server: server, defaults: defaults, fetch: fetch)
        #expect(counter.count == 2)
    }

    @Test func onlyTheZonesOfTheServersKeptRemain() throws {
        let other = Server.fake()
        try WatchZoneSync.replaceZones(
            [AppZone(entityId: "zone.home", serverIdentifier: server.identifier.rawValue)],
            for: server.identifier
        )
        try WatchZoneSync.replaceZones(
            [AppZone(entityId: "zone.work", serverIdentifier: other.identifier.rawValue)],
            for: other.identifier
        )

        WatchZoneSync.removeZones(exceptFor: [server.identifier], defaults: defaults)

        #expect(storedZones(of: server).map(\.entityId) == ["zone.home"])
        #expect(storedZones(of: other).isEmpty)
    }
}

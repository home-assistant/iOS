import CoreLocation
import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

final class LocationBasedServerSwitcherTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousServers: ServerManager!
    private var servers: FakeServerManager!
    private var server1: Server!
    private var server2: Server!

    // Two far-apart home zones, roughly San Francisco and New York.
    private let home1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    private let home2 = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)

    override func setUpWithError() throws {
        try super.setUpWithError()

        database = try DatabaseQueue()
        try AppZoneTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { self.database }

        servers = FakeServerManager(initial: 2)
        server1 = servers.all[0]
        server2 = servers.all[1]
        previousServers = Current.servers
        Current.servers = servers
    }

    override func tearDown() {
        Current.database = previousDatabase
        Current.servers = previousServers
        super.tearDown()
    }

    private func addZone(
        entityId: String = "zone.home",
        server: Server,
        center: CLLocationCoordinate2D,
        radius: Double = 100,
        trackingEnabled: Bool = true
    ) {
        AppZone(
            entityId: entityId,
            serverIdentifier: server.identifier.rawValue,
            latitude: center.latitude,
            longitude: center.longitude,
            radius: radius,
            trackingEnabled: trackingEnabled
        ).save()
    }

    private func location(at coordinate: CLLocationCoordinate2D) -> CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    func testMatchesOtherServerWhenInsideItsZone() {
        addZone(server: server1, center: home1)
        addZone(server: server2, center: home2)

        let matched = LocationBasedServerSwitcher.matchedServer(
            for: location(at: home2),
            preferring: server1.identifier
        )

        XCTAssertEqual(matched?.identifier, server2.identifier)
    }

    func testMatchesCurrentServerWhenInsideItsZone() {
        addZone(server: server1, center: home1)
        addZone(server: server2, center: home2)

        let matched = LocationBasedServerSwitcher.matchedServer(
            for: location(at: home1),
            preferring: server1.identifier
        )

        XCTAssertEqual(matched?.identifier, server1.identifier)
    }

    func testReturnsNilWhenNoZoneContainsTheLocation() {
        addZone(server: server1, center: home1)
        addZone(server: server2, center: home2)

        let matched = LocationBasedServerSwitcher.matchedServer(
            for: location(at: .init(latitude: 51.5074, longitude: -0.1278)),
            preferring: server1.identifier
        )

        XCTAssertNil(matched)
    }

    func testPrefersCurrentServerWhenZonesOverlap() {
        // Both servers claim the same location; the other server's zone is even smaller, which
        // would win on size — the current server must still be preferred so the user stays put.
        addZone(server: server1, center: home1, radius: 500)
        addZone(server: server2, center: home1, radius: 100)

        let matched = LocationBasedServerSwitcher.matchedServer(
            for: location(at: home1),
            preferring: server1.identifier
        )

        XCTAssertEqual(matched?.identifier, server1.identifier)
    }

    func testSmallestZoneWinsAmongOtherServers() {
        let server3 = servers.addFake()
        addZone(server: server1, center: home1)
        addZone(server: server2, center: home2, radius: 500)
        addZone(server: server3, center: home2, radius: 100)

        let matched = LocationBasedServerSwitcher.matchedServer(
            for: location(at: home2),
            preferring: server1.identifier
        )

        XCTAssertEqual(matched?.identifier, server3.identifier)
    }

    func testIgnoresZonesWithTrackingDisabled() {
        addZone(server: server1, center: home1)
        addZone(server: server2, center: home2, trackingEnabled: false)

        let matched = LocationBasedServerSwitcher.matchedServer(
            for: location(at: home2),
            preferring: server1.identifier
        )

        XCTAssertNil(matched)
    }

    func testClosestServerIsTheOneWithTheNearestZone() throws {
        addZone(server: server1, center: home1)
        addZone(server: server2, center: home2)

        // Slightly north of server2's home: far from both zones, but nearer to server2's.
        let nearHome2 = CLLocation(latitude: home2.latitude + 0.1, longitude: home2.longitude)
        let closest = try XCTUnwrap(LocationBasedServerSwitcher.closestServer(to: nearHome2))

        XCTAssertEqual(closest.server.identifier, server2.identifier)
        XCTAssertEqual(closest.distance, nearHome2.distance(from: location(at: home2)), accuracy: 1)
    }

    func testClosestServerUsesEachServersNearestZone() throws {
        // Server1 has a faraway home but also a nearby secondary zone, which should represent it.
        addZone(server: server1, center: home1)
        addZone(entityId: "zone.office", server: server1, center: .init(
            latitude: home2.latitude + 0.01,
            longitude: home2.longitude
        ))
        addZone(server: server2, center: home2)

        let atHome2 = location(at: home2)
        let closest = try XCTUnwrap(LocationBasedServerSwitcher.closestServer(to: atHome2))

        XCTAssertEqual(closest.server.identifier, server2.identifier)
        XCTAssertEqual(closest.distance, 0, accuracy: 1)
    }

    func testClosestServerIsNilWithoutZones() {
        XCTAssertNil(LocationBasedServerSwitcher.closestServer(to: location(at: home1)))
    }
}

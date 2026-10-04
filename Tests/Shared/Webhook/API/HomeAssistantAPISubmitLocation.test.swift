import CoreLocation
import Foundation
import GRDB
import PromiseKit
@testable import Shared
import XCTest

final class HomeAssistantAPISubmitLocationTests: XCTestCase {
    private var webhookManager: FakeWebhookManager!
    private var previousWebhookManager: WebhookManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var database: DatabaseQueue!
    private var sent = [(identifier: WebhookResponseIdentifier, request: WebhookRequest)]()

    override func setUpWithError() throws {
        try super.setUpWithError()
        let database = try DatabaseQueue()
        try LocationHistoryTable().createIfNeeded(database: database)
        self.database = database
        previousDatabase = Current.database
        Current.database = { database }

        previousWebhookManager = Current.webhooks
        webhookManager = FakeWebhookManager()
        Current.webhooks = webhookManager
        sent = []
        webhookManager.sendRequestHandler = { [weak self] identifier, _, request, seal in
            self?.sent.append((identifier, request))
            seal.fulfill(())
        }
    }

    override func tearDown() {
        Current.webhooks = previousWebhookManager
        Current.database = previousDatabase
        database = nil
        super.tearDown()
    }

    private func makeAPI(
        privacy: ServerLocationPrivacy,
        version: Version = "2021.1.0"
    ) -> HomeAssistantAPI {
        HomeAssistantAPI(server: .fake(update: { info in
            info.version = version
            info.setSetting(value: privacy, for: .locationPrivacy)
        }))
    }

    private func locationPayload() throws -> [String: Any] {
        let location = try XCTUnwrap(sent.first { $0.identifier == .location })
        XCTAssertEqual(location.request.type, "update_location")
        XCTAssertNotNil(location.request.localMetadata)
        return try XCTUnwrap(location.request.data as? [String: Any])
    }

    private func storedHistory() throws -> [LocationHistoryEntry] {
        try database.read { db in
            try LocationHistoryEntry.fetchAll(db)
        }
    }

    private var workZone: AppZone {
        AppZone(
            entityId: "zone.work",
            serverIdentifier: "server",
            latitude: 10,
            longitude: 20,
            radius: 50
        )
    }

    func testExactPrivacySendsTheZoneCoordinates() throws {
        let api = makeAPI(privacy: .exact)

        try hang(api.SubmitLocation(updateType: .GPSRegionEnter, location: nil, zone: workZone))

        let payload = try locationPayload()
        XCTAssertNotNil(payload["gps"])
        XCTAssertEqual(payload["gps_accuracy"] as? Double, 50)

        let history = try storedHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.trigger, LocationUpdateTrigger.GPSRegionEnter.rawValue)
        XCTAssertEqual(history.first?.zoneIdentifier, workZone.identifier)
        XCTAssertEqual(history.first?.latitude, 10)
        XCTAssertEqual(history.first?.longitude, 20)
    }

    func testNeverPrivacySendsNoLocation() throws {
        let api = makeAPI(privacy: .never)

        try hang(api.SubmitLocation(updateType: .GPSRegionEnter, location: nil, zone: workZone))

        let payload = try locationPayload()
        XCTAssertNil(payload["gps"])
        XCTAssertNil(payload["location_name"])
        XCTAssertEqual(try storedHistory().count, 1)
    }

    func testZoneOnlyPrivacyWithoutLocationSendsNothingAboutWhere() throws {
        let api = makeAPI(privacy: .zoneOnly)

        try hang(api.SubmitLocation(updateType: .Manual, location: nil, zone: nil))

        let payload = try locationPayload()
        XCTAssertNil(payload["gps"])
        XCTAssertNil(payload["location_name"])
        XCTAssertNil(payload["in_zones"])
    }

    func testZoneOnlyPrivacyNamesTheBeaconZoneOnOlderServers() throws {
        let api = makeAPI(privacy: .zoneOnly)

        try hang(api.SubmitLocation(updateType: .BeaconRegionEnter, location: nil, zone: workZone))

        let payload = try locationPayload()
        XCTAssertNil(payload["gps"])
        XCTAssertEqual(payload["location_name"] as? String, "work")
        XCTAssertNil(payload["in_zones"])
    }

    func testZoneOnlyPrivacyReportsInZonesOnNewerServers() throws {
        let api = makeAPI(privacy: .zoneOnly, version: "2026.6.0")

        try hang(api.SubmitLocation(updateType: .BeaconRegionEnter, location: nil, zone: workZone))

        let payload = try locationPayload()
        XCTAssertNil(payload["gps"])
        XCTAssertEqual(payload["location_name"] as? String, "work")
        XCTAssertEqual(payload["in_zones"] as? [String], ["zone.work"])
    }

    func testZoneOnlyPrivacyIgnoresAnUntrackedBeaconZone() throws {
        let api = makeAPI(privacy: .zoneOnly, version: "2026.6.0")
        let untracked = AppZone(entityId: "zone.gym", serverIdentifier: "server", trackingEnabled: false)

        try hang(api.SubmitLocation(updateType: .BeaconRegionEnter, location: nil, zone: untracked))

        let payload = try locationPayload()
        XCTAssertEqual(payload["location_name"] as? String, LocationNames.NotHome.rawValue)
        XCTAssertEqual(payload["in_zones"] as? [String], [])
    }
}

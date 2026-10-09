import CoreLocation
import GRDB
import PromiseKit
@testable import Shared
import XCTest

final class HomeAssistantAPISubmitLocationTests: XCTestCase {
    private var webhookManager: FakeWebhookManager!
    private var previousWebhookManager: WebhookManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousGeocode: ((CLLocation) -> Promise<[CLPlacemark]>)!

    private let fix = CLLocation(
        coordinate: .init(latitude: 52.37, longitude: 4.89),
        altitude: 2,
        horizontalAccuracy: 8,
        verticalAccuracy: 4,
        timestamp: Date()
    )

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousWebhookManager = Current.webhooks
        webhookManager = FakeWebhookManager()
        Current.webhooks = webhookManager

        previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try AppZoneTable().createIfNeeded(database: database)
        try LocationHistoryTable().createIfNeeded(database: database)
        Current.database = { database }
        Current.device.batteries = { [DeviceBattery(level: 44, state: .charging, attributes: [:])] }
        // The sensors sent alongside an exact location include a reverse geocode, kept off the network.
        previousGeocode = Current.geocoder.geocode
        Current.geocoder.geocode = { _ in .value([]) }
    }

    override func tearDown() {
        Current.webhooks = previousWebhookManager
        Current.database = previousDatabase
        Current.geocoder.geocode = previousGeocode
        super.tearDown()
    }

    /// Submits `fix` under `privacy` and returns the `update_location` payload that went out.
    private func submit(privacy: ServerLocationPrivacy) throws -> [String: Any] {
        let server = Server.fake {
            $0.version = .inZonesOnLocationUpdate
            $0.setSetting(value: privacy, for: .locationPrivacy)
        }
        AppZone(
            entityId: "zone.home",
            serverIdentifier: server.identifier.rawValue,
            latitude: 52.37,
            longitude: 4.89,
            radius: 100
        ).save()

        var locationPayload: [String: Any]?
        webhookManager.sendRequestHandler = { _, _, request, seal in
            if request.type == "update_location" {
                locationPayload = request.data as? [String: Any]
            }
            seal.fulfill(())
        }

        try hang(HomeAssistantAPI(server: server).SubmitLocation(updateType: .Manual, location: fix, zone: nil))
        return try XCTUnwrap(locationPayload)
    }

    func testExactSendsTheFix() throws {
        let payload = try submit(privacy: .exact)

        XCTAssertEqual(payload["gps"] as? [Double], [52.37, 4.89])
        XCTAssertNil(payload["location_name"])
    }

    func testZoneOnlySendsTheZoneTheFixFallsIn() throws {
        let payload = try submit(privacy: .zoneOnly)

        XCTAssertNil(payload["gps"])
        XCTAssertEqual(payload["location_name"] as? String, "home")
        XCTAssertEqual(payload["in_zones"] as? [String], ["zone.home"])
    }

    func testNeverSendsNoLocation() throws {
        let payload = try submit(privacy: .never)

        XCTAssertNil(payload["gps"])
        XCTAssertNil(payload["location_name"])
        XCTAssertEqual(payload["battery"] as? Int, 44)
    }
}

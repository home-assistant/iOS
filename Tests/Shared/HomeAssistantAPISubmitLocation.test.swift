import CoreLocation
import PromiseKit
@testable import Shared
import XCTest

final class HomeAssistantAPISubmitLocationTests: XCTestCase {
    private var webhookManager: FakeWebhookManager!
    private var previousWebhookManager: WebhookManager!
    private var locationPayload: [String: Any]?

    override func setUp() {
        super.setUp()
        previousWebhookManager = Current.webhooks
        webhookManager = FakeWebhookManager()
        webhookManager.sendRequestHandler = { [weak self] identifier, _, request, seal in
            if identifier == .location {
                self?.locationPayload = request.data as? [String: Any]
            }
            seal.fulfill(())
        }
        Current.webhooks = webhookManager
    }

    override func tearDown() {
        Current.webhooks = previousWebhookManager
        ServerFixture.reset()
        locationPayload = nil
        super.tearDown()
    }

    func testSendsLocationTimeToCoreThatSupportsIt() throws {
        let fixTime = Date(timeIntervalSince1970: 1_790_426_575.123)
        let server = ServerFixture.standard
        server.info.version = Version(major: 2026, minor: 11, patch: 0)

        try hang(HomeAssistantAPI(server: server).SubmitLocation(
            updateType: .Manual,
            location: location(timestamp: fixTime),
            zone: nil
        ))

        let payload = try XCTUnwrap(locationPayload)
        let locationTime = try XCTUnwrap(payload["location_time"] as? String)
        let parsed = try XCTUnwrap(DateFormatter.iso8601Milliseconds.date(from: locationTime))
        XCTAssertEqual(parsed.timeIntervalSince1970, fixTime.timeIntervalSince1970, accuracy: 0.001)
    }

    func testOmitsLocationTimeForOlderCore() throws {
        let server = ServerFixture.standard
        server.info.version = Version(major: 2026, minor: 10, patch: 0)

        try hang(HomeAssistantAPI(server: server).SubmitLocation(
            updateType: .Manual,
            location: location(timestamp: Date()),
            zone: nil
        ))

        let payload = try XCTUnwrap(locationPayload)
        XCTAssertNotNil(payload["gps"])
        XCTAssertNil(payload["location_time"])
    }

    private func location(timestamp: Date) -> CLLocation {
        CLLocation(
            coordinate: .init(latitude: 1.23, longitude: 4.56),
            altitude: 103,
            horizontalAccuracy: 104,
            verticalAccuracy: 105,
            timestamp: timestamp
        )
    }
}

import Foundation
import PromiseKit
@testable import Shared
import XCTest

/// `register_sensor` is the only call that describes a sensor, so an app update has to send it
/// again for the entities Home Assistant already has.
class RegisterSensorsForAppVersionTests: XCTestCase {
    private var api: HomeAssistantAPI!
    private var webhookManager: FakeWebhookManager!
    private var previousWebhookManager: WebhookManager!

    override func setUp() {
        super.setUp()

        api = HomeAssistantAPI(server: .fake())
        webhookManager = FakeWebhookManager()
        previousWebhookManager = Current.webhooks
        Current.webhooks = webhookManager
    }

    override func tearDown() {
        super.tearDown()

        Current.webhooks = previousWebhookManager
        SensorRegistrationVersionStore.forgetRegistration(for: api.server.identifier)
    }

    /// Answers every registration, counting them.
    private func acceptRegistrations() -> () -> [WebhookRequest] {
        var requests = [WebhookRequest]()
        webhookManager.sendRequestHandler = { _, _, request, seal in
            requests.append(request)
            seal.fulfill(())
        }
        return { requests }
    }

    func testAFullPassRecordsTheVersion() throws {
        let requests = acceptRegistrations()

        try hang(api.registerSensors())

        XCTAssertFalse(requests().isEmpty)
        XCTAssertTrue(requests().allSatisfy { $0.type == "register_sensor" })
        XCTAssertFalse(SensorRegistrationVersionStore.needsRegistration(for: api.server.identifier))
    }

    func testRegisteringOneSensorLeavesTheVersionAlone() throws {
        _ = acceptRegistrations()

        try hang(api.registerSensors(limitedToUniqueIDs: [WebhookSensorId.appVersion.rawValue]))

        XCTAssertTrue(SensorRegistrationVersionStore.needsRegistration(for: api.server.identifier))
    }

    func testAnUpgradedInstallRegistersEverythingOnce() throws {
        let requests = acceptRegistrations()

        try hang(api.registerSensorsIfAppVersionChanged())
        let afterFirstRun = requests().count
        XCTAssertGreaterThan(afterFirstRun, 0)

        // Nothing left to say until the app updates again.
        try hang(api.registerSensorsIfAppVersionChanged())
        XCTAssertEqual(requests().count, afterFirstRun)
    }

    func testAFailedPassIsLeftForTheNextConnection() throws {
        webhookManager.sendRequestHandler = { _, _, _, seal in
            seal.reject(TestError.any)
        }

        // Recovered, so a failure here can't fail the connection it runs as part of.
        try hang(api.registerSensorsIfAppVersionChanged())

        XCTAssertTrue(SensorRegistrationVersionStore.needsRegistration(for: api.server.identifier))
    }

    private enum TestError: Error {
        case any
    }
}

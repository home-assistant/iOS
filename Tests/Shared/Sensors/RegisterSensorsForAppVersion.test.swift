import Foundation
import PromiseKit
@testable import Shared
import XCTest

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

    @discardableResult
    private func acceptRegistrations() -> () -> [WebhookRequest] {
        var requests = [WebhookRequest]()
        webhookManager.sendRequestHandler = { _, _, request, seal in
            requests.append(request)
            seal.fulfill(())
        }
        return { requests }
    }

    private func rejectRegistrations() {
        webhookManager.sendRequestHandler = { _, _, _, seal in
            seal.reject(TestError.any)
        }
    }

    private func payloads(in requests: [WebhookRequest]) -> [[String: Any]] {
        requests.compactMap { $0.data as? [String: Any] }
    }

    func testAFullPassRecordsTheVersion() throws {
        let requests = acceptRegistrations()

        try hang(api.registerSensors())

        XCTAssertFalse(requests().isEmpty)
        XCTAssertTrue(requests().allSatisfy { $0.type == "register_sensor" })
        XCTAssertFalse(SensorRegistrationVersionStore.needsRegistration(for: api.server.identifier))
    }

    func testRegisteringOneSensorLeavesTheVersionAlone() throws {
        acceptRegistrations()

        try hang(api.registerSensors(limitedToUniqueIDs: [WebhookSensorId.appVersion.rawValue]))

        XCTAssertTrue(SensorRegistrationVersionStore.needsRegistration(for: api.server.identifier))
    }

    func testAFailedPassLeavesTheVersionAlone() throws {
        rejectRegistrations()

        XCTAssertThrowsError(try hang(api.registerSensors()))

        XCTAssertTrue(SensorRegistrationVersionStore.needsRegistration(for: api.server.identifier))
    }

    func testRegistrationCarriesTheEntityCategory() throws {
        let requests = acceptRegistrations()

        try hang(api.registerSensors())

        let sent = payloads(in: requests())
        let appVersionID = WebhookSensorId.appVersion.rawValue
        let appVersion = try XCTUnwrap(sent.first { $0["unique_id"] as? String == appVersionID })
        XCTAssertEqual(appVersion["entity_category"] as? String, "diagnostic")

        for payload in sent {
            let uniqueID = try XCTUnwrap(payload["unique_id"] as? String)
            XCTAssertEqual(
                payload["entity_category"] as? String,
                SensorEntityCategory.category(forSensorUniqueID: uniqueID)?.rawValue,
                uniqueID
            )
        }
    }

    func testAStateUpdateCarriesNoEntityCategory() throws {
        var sent = [WebhookRequest]()
        webhookManager.sendRequestHandler = { _, _, request, seal in
            sent.append(request)
            seal.fulfill(())
        }

        try hang(api.UpdateSensors(trigger: .Manual))

        let payloads = sent.flatMap { $0.data as? [[String: Any]] ?? [] }
        XCTAssertFalse(payloads.isEmpty)
        XCTAssertTrue(payloads.allSatisfy { $0["entity_category"] == nil })
    }

    func testAnUpgradedInstallRegistersEverythingOnce() throws {
        let requests = acceptRegistrations()

        try hang(api.registerSensorsIfAppVersionChanged())
        let afterFirstRun = requests().count
        XCTAssertGreaterThan(afterFirstRun, 0)

        try hang(api.registerSensorsIfAppVersionChanged())

        XCTAssertEqual(requests().count, afterFirstRun)
    }

    func testAnInstallThatNeverUpgradedRegistersNothing() throws {
        let requests = acceptRegistrations()
        SensorRegistrationVersionStore.recordRegistration(for: api.server.identifier)

        try hang(api.registerSensorsIfAppVersionChanged())

        XCTAssertTrue(requests().isEmpty)
    }

    func testAFailedPassIsRecoveredAndRetriedByTheNextConnection() throws {
        rejectRegistrations()

        XCTAssertNoThrow(try hang(api.registerSensorsIfAppVersionChanged()))
        XCTAssertTrue(SensorRegistrationVersionStore.needsRegistration(for: api.server.identifier))

        let requests = acceptRegistrations()
        try hang(api.registerSensorsIfAppVersionChanged())

        XCTAssertFalse(requests().isEmpty)
        XCTAssertFalse(SensorRegistrationVersionStore.needsRegistration(for: api.server.identifier))
    }

    private enum TestError: Error {
        case any
    }
}

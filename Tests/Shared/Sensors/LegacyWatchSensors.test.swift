import Foundation
import ObjectMapper
import PromiseKit
@testable import Shared
import XCTest

final class LegacyWatchSensorsTests: XCTestCase {
    private var server: Server!
    private var servers: FakeServerManager!
    private var previousServers: ServerManager!
    private var webhookManager: FakeWebhookManager!
    private var previousWebhookManager: WebhookManager!

    private let levelID = WebhookSensorId.watchBattery.rawValue
    private let stateID = WebhookSensorId.watchBatteryState.rawValue

    override func setUp() {
        super.setUp()
        servers = FakeServerManager()
        server = servers.addFake()
        previousServers = Current.servers
        Current.servers = servers
        webhookManager = FakeWebhookManager()
        previousWebhookManager = Current.webhooks
        Current.webhooks = webhookManager
    }

    override func tearDown() {
        Current.webhooks = previousWebhookManager
        Current.servers = previousServers
        LegacyWatchSensors.forgetRetired(for: server.identifier)
        super.tearDown()
    }

    private func config(entities: [String: Any]?) throws -> ConfigResponse {
        var json: [String: Any] = ["version": "2026.9.3"]
        if let entities {
            json["entities"] = entities
        }
        return try XCTUnwrap(ConfigResponse(JSON: json))
    }

    private func entity(disabled: Bool) -> [String: Any] {
        ["disabled": disabled]
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

    func testTheConfigResponseListsTheEntities() throws {
        let config = try config(entities: [
            levelID: entity(disabled: false),
            "battery_level": entity(disabled: true),
        ])

        XCTAssertEqual(config.entities?[levelID], ConfigResponseEntity(disabled: false))
        XCTAssertEqual(config.entities?["battery_level"], ConfigResponseEntity(disabled: true))
        XCTAssertNil(config.entities?[stateID])
    }

    func testNeedsRetiringUntilTheServerHasBeenSettled() throws {
        let config = try config(entities: [levelID: entity(disabled: false)])

        XCTAssertTrue(LegacyWatchSensors.needsRetiring(reportedBy: config, on: server))

        LegacyWatchSensors.recordRetired(for: server.identifier)

        XCTAssertFalse(LegacyWatchSensors.needsRetiring(reportedBy: config, on: server))
    }

    func testDoesNotNeedRetiringWhenTheServerCannotListItsEntities() throws {
        let config = try config(entities: nil)

        XCTAssertFalse(LegacyWatchSensors.needsRetiring(reportedBy: config, on: server))
    }

    func testDisablesTheSensorsTheServerStillHasEnabled() async throws {
        let requests = acceptRegistrations()
        let config = try config(entities: [
            levelID: entity(disabled: false),
            stateID: entity(disabled: false),
        ])

        await LegacyWatchSensors.retire(reportedBy: config, on: server)

        XCTAssertTrue(requests().allSatisfy { $0.type == "register_sensor" })
        let sent = payloads(in: requests())
        XCTAssertEqual(Set(sent.compactMap { $0["unique_id"] as? String }), [levelID, stateID])
        XCTAssertTrue(sent.allSatisfy { $0["disabled"] as? Bool == true })
        XCTAssertTrue(sent.allSatisfy { $0["type"] as? String == "sensor" })
        XCTAssertTrue(sent.allSatisfy { $0["entity_category"] as? String == "diagnostic" })
        XCTAssertTrue(sent.allSatisfy { ($0["name"] as? String)?.isEmpty == false })
        XCTAssertTrue(LegacyWatchSensors.hasRetired(for: server.identifier))
    }

    func testDisablesOnlyTheOneStillEnabled() async throws {
        let requests = acceptRegistrations()
        let config = try config(entities: [
            levelID: entity(disabled: true),
            stateID: entity(disabled: false),
        ])

        await LegacyWatchSensors.retire(reportedBy: config, on: server)

        XCTAssertEqual(payloads(in: requests()).compactMap { $0["unique_id"] as? String }, [stateID])
    }

    func testLeavesAlreadyDisabledSensorsAlone() async throws {
        let requests = acceptRegistrations()
        let config = try config(entities: [
            levelID: entity(disabled: true),
            stateID: entity(disabled: true),
        ])

        await LegacyWatchSensors.retire(reportedBy: config, on: server)

        XCTAssertTrue(requests().isEmpty)
        XCTAssertTrue(LegacyWatchSensors.hasRetired(for: server.identifier))
    }

    func testNeverCreatesSensorsTheServerDoesNotHave() async throws {
        let requests = acceptRegistrations()
        let config = try config(entities: [
            "battery_level": entity(disabled: false),
        ])

        await LegacyWatchSensors.retire(reportedBy: config, on: server)

        XCTAssertTrue(requests().isEmpty)
        XCTAssertTrue(LegacyWatchSensors.hasRetired(for: server.identifier))
    }

    func testAServerTooOldToListItsEntitiesIsAskedAgain() async throws {
        let requests = acceptRegistrations()
        let config = try config(entities: nil)

        await LegacyWatchSensors.retire(reportedBy: config, on: server)

        XCTAssertTrue(requests().isEmpty)
        XCTAssertFalse(LegacyWatchSensors.hasRetired(for: server.identifier))
    }

    func testASensorTheUserSwitchedBackOnStaysOn() async throws {
        let requests = acceptRegistrations()
        let config = try config(entities: [
            levelID: entity(disabled: false),
            stateID: entity(disabled: false),
        ])

        await LegacyWatchSensors.retire(reportedBy: config, on: server)
        let afterFirstRun = requests().count
        XCTAssertEqual(afterFirstRun, 2)

        await LegacyWatchSensors.retire(reportedBy: config, on: server)

        XCTAssertEqual(requests().count, afterFirstRun)
    }

    func testAFailedRequestIsRetriedByTheNextConnection() async throws {
        rejectRegistrations()
        let config = try config(entities: [
            levelID: entity(disabled: false),
            stateID: entity(disabled: false),
        ])

        await LegacyWatchSensors.retire(reportedBy: config, on: server)

        XCTAssertFalse(LegacyWatchSensors.hasRetired(for: server.identifier))

        let requests = acceptRegistrations()
        await LegacyWatchSensors.retire(reportedBy: config, on: server)

        XCTAssertEqual(requests().count, 2)
        XCTAssertTrue(LegacyWatchSensors.hasRetired(for: server.identifier))
    }

    func testAServerStillBeingOnboardedIsLeftAlone() async throws {
        let detached = Server.fake()
        defer { LegacyWatchSensors.forgetRetired(for: detached.identifier) }
        let requests = acceptRegistrations()
        let config = try config(entities: [levelID: entity(disabled: false)])

        XCTAssertFalse(LegacyWatchSensors.needsRetiring(reportedBy: config, on: detached))

        await LegacyWatchSensors.retire(reportedBy: config, on: detached)

        XCTAssertTrue(requests().isEmpty)
        XCTAssertFalse(LegacyWatchSensors.hasRetired(for: detached.identifier))
    }

    func testServersAreTrackedApart() async throws {
        let other = servers.addFake()
        defer { LegacyWatchSensors.forgetRetired(for: other.identifier) }
        let requests = acceptRegistrations()
        let config = try config(entities: [
            levelID: entity(disabled: false),
        ])

        await LegacyWatchSensors.retire(reportedBy: config, on: server)

        XCTAssertFalse(LegacyWatchSensors.hasRetired(for: other.identifier))

        await LegacyWatchSensors.retire(reportedBy: config, on: other)

        XCTAssertEqual(requests().count, 2)
        XCTAssertTrue(LegacyWatchSensors.hasRetired(for: other.identifier))
    }

    func testOverlappingRunsForOneServerSendEachRequestOnce() async throws {
        let config = try config(entities: [
            levelID: entity(disabled: false),
            stateID: entity(disabled: false),
        ])
        let pending = PendingRequests()
        webhookManager.sendRequestHandler = { _, _, request, seal in
            pending.add(request, seal)
        }

        let first = Task { await LegacyWatchSensors.retire(reportedBy: config, on: server) }
        await pending.waitForCount(1)

        XCTAssertFalse(LegacyWatchSensors.needsRetiring(reportedBy: config, on: server))
        let second = Task { await LegacyWatchSensors.retire(reportedBy: config, on: server) }
        await second.value
        XCTAssertEqual(pending.count, 1)

        pending.fulfillAll()
        await pending.waitForCount(2)
        pending.fulfillAll()
        await first.value

        XCTAssertEqual(pending.count, 2)
        XCTAssertTrue(LegacyWatchSensors.hasRetired(for: server.identifier))
    }

    func testAFailedRunReleasesTheServerForTheNextOne() async throws {
        rejectRegistrations()
        let config = try config(entities: [levelID: entity(disabled: false)])

        await LegacyWatchSensors.retire(reportedBy: config, on: server)

        XCTAssertTrue(LegacyWatchSensors.needsRetiring(reportedBy: config, on: server))
    }

    func testFetchingTheConfigDisablesThem() throws {
        let api = HomeAssistantAPI(server: server)
        let registered = expectation(description: "both legacy sensors disabled")
        registered.expectedFulfillmentCount = 2
        var sent = [WebhookRequest]()
        webhookManager.sendRequestHandler = { _, _, request, seal in
            sent.append(request)
            seal.fulfill(())
            registered.fulfill()
        }
        webhookManager.sendEphemeralHandler = { [levelID, stateID] _, request in
            XCTAssertEqual(request.type, "get_config")
            return [
                "version": "2026.9.3",
                "entities": [
                    levelID: ["disabled": false],
                    stateID: ["disabled": false],
                ],
            ]
        }

        try hang(api.getConfig())

        wait(for: [registered], timeout: 5)
        XCTAssertEqual(
            Set(payloads(in: sent).compactMap { $0["unique_id"] as? String }),
            [levelID, stateID]
        )
        XCTAssertTrue(payloads(in: sent).allSatisfy { $0["disabled"] as? Bool == true })
    }

    private enum TestError: Error {
        case any
    }

    private final class PendingRequests {
        private let lock = NSLock()
        private var requests = [WebhookRequest]()
        private var seals = [Resolver<Void>]()

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return requests.count
        }

        func add(_ request: WebhookRequest, _ seal: Resolver<Void>) {
            lock.lock()
            defer { lock.unlock() }
            requests.append(request)
            seals.append(seal)
        }

        func fulfillAll() {
            lock.lock()
            let pending = seals
            seals.removeAll()
            lock.unlock()
            pending.forEach { $0.fulfill(()) }
        }

        func waitForCount(_ expected: Int) async {
            while count < expected {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
    }
}

import Foundation
import HAKit
@testable import Shared
import XCTest

/// Running a magic item from the phone: what goes over the WebSocket connection for each item type
/// and lock state, and how the outcome is reported. XCTest because the API cache in `Current` is
/// swapped for one holding a scripted connection.
final class MagicItemExecuteTests: XCTestCase {
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var server: Server!
    private var connection: MagicItemTestConnection!

    override func setUp() {
        super.setUp()
        previousCachedApis = Current.cachedApis

        server = Server.fake()
        connection = MagicItemTestConnection()
        connection.responses["call_service"] = .success(.empty)
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
    }

    override func tearDown() {
        Current.cachedApis = previousCachedApis
        connection = nil
        server = nil
        super.tearDown()
    }

    private func run(_ item: MagicItem, state: String = "", on server: Server? = nil) -> (Bool, Error?) {
        let finished = expectation(description: "completion")
        var outcome: (Bool, Error?) = (false, nil)
        item.execute(on: server ?? self.server!, source: .Widget, currentItemState: state) { success, error in
            outcome = (success, error)
            finished.fulfill()
        }
        wait(for: [finished], timeout: 10)
        return outcome
    }

    private func lastService() -> String? {
        connection.sentRequests.last?.data["service"] as? String
    }

    private func lastTargetEntityId() -> String? {
        (connection.sentRequests.last?.data["target"] as? [String: Any])?["entity_id"] as? String
    }

    func testEntityRunsItsDomainsMainAction() {
        let (success, error) = run(MagicItem(id: "light.kitchen", serverId: "1", type: .entity))

        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertEqual(connection.sentRequests.count, 1)
        XCTAssertEqual(connection.sentRequests.first?.type.command, "call_service")
        XCTAssertEqual(connection.sentRequests.first?.data["domain"] as? String, "light")
        XCTAssertEqual(lastService(), Service.toggle.rawValue)
        XCTAssertEqual(lastTargetEntityId(), "light.kitchen")
    }

    func testLockedLockIsUnlockedAndUnlockedLockIsLocked() {
        let lock = MagicItem(id: "lock.front", serverId: "1", type: .entity)

        XCTAssertTrue(run(lock, state: "locked").0)
        XCTAssertEqual(lastService(), Service.unlock.rawValue)

        XCTAssertTrue(run(lock, state: "locking").0)
        XCTAssertEqual(lastService(), Service.unlock.rawValue)

        XCTAssertTrue(run(lock, state: "unlocked").0)
        XCTAssertEqual(lastService(), Service.lock.rawValue)
        XCTAssertEqual(lastTargetEntityId(), "lock.front")

        XCTAssertTrue(run(lock, state: "unlocking").0)
        XCTAssertEqual(lastService(), Service.lock.rawValue)
        XCTAssertEqual(connection.sentRequests.count, 4)
    }

    func testLockWithoutAnActionableStateSendsNothing() {
        let lock = MagicItem(id: "lock.front", serverId: "1", type: .entity)

        XCTAssertTrue(run(lock, state: "jammed").0)
        XCTAssertTrue(run(lock, state: "").0)
        XCTAssertTrue(connection.sentRequests.isEmpty)
    }

    func testDomainWithoutAMainActionSendsNothing() {
        let (success, error) = run(MagicItem(id: "sensor.power", serverId: "1", type: .entity))

        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertTrue(connection.sentRequests.isEmpty)
    }

    func testItemsWithoutADirectActionSucceedWithoutSendingAnything() {
        for type in [
            MagicItem.ItemType.folder,
            .area,
            .complication,
            .assistPipeline,
            .assistPrompt,
            .unsupported,
        ] {
            let (success, error) = run(MagicItem(id: "item", serverId: "1", type: type))
            XCTAssertTrue(success, "\(type)")
            XCTAssertNil(error, "\(type)")
        }
        XCTAssertTrue(connection.sentRequests.isEmpty)
    }

    func testEntityWithAnUnknownDomainFails() {
        let (success, error) = run(MagicItem(id: "not_a_domain.thing", serverId: "1", type: .entity))

        XCTAssertFalse(success)
        guard case .unknownDomain = error as? MagicItemError else {
            return XCTFail("Expected unknownDomain, got \(String(describing: error))")
        }
        XCTAssertTrue(connection.sentRequests.isEmpty)
    }

    func testRejectedServiceCallIsReported() {
        connection.responses["call_service"] = .failure(.internal(debugDescription: "unit-test"))

        let (success, error) = run(MagicItem(id: "switch.porch", serverId: "1", type: .entity))

        XCTAssertFalse(success)
        XCTAssertNotNil(error)
        XCTAssertEqual(connection.sentRequests.count, 1)
    }

    func testServerWithoutAURLFailsInsteadOfStayingSilent() {
        let unreachable = Server.fake { info in
            info.connection = ConnectionInfo(
                externalURL: nil,
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .undefined
            )
        }

        let (success, error) = run(
            MagicItem(id: "light.kitchen", serverId: unreachable.identifier.rawValue, type: .entity),
            on: unreachable
        )

        XCTAssertFalse(success)
        guard case .noActiveURL = error as? ServerConnectionError else {
            return XCTFail("Expected noActiveURL, got \(String(describing: error))")
        }
    }
}

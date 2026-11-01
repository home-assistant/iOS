#if canImport(ActivityKit)
import Foundation
@testable import Shared
import XCTest

/// The push-to-start token stream only delivers tokens issued while the app observes it. These tests
/// cover the reconciliation that catches a token the system rotated while the app was not running
/// (home-assistant/iOS#5812), so the stale one stops being re-sent to Core on every registration.
@available(iOS 17.2, *)
final class LiveActivityPushToStartTokenSyncTests: XCTestCase {
    /// What the registry touched: the stored token (an in-memory stand-in for the Keychain, which the
    /// test host cannot access) and the servers that received an `update_registration` request.
    private final class Recorder: @unchecked Sendable {
        var storedToken: String?
        var updatedServers: [Identifier<Server>] = []
        init(storedToken: String?) { self.storedToken = storedToken }
    }

    private var previousServers: ServerManager!
    private var previousWebhooks: WebhookManager!
    private var previousVendorID: (() -> String?)!
    private var servers: FakeServerManager!
    private var webhooks: FakeWebhookManager!
    private var recorder: Recorder!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        previousWebhooks = Current.webhooks
        previousVendorID = Current.device.identifierForVendor
        servers = FakeServerManager(initial: 2)
        webhooks = FakeWebhookManager()
        recorder = Recorder(storedToken: nil)
        Current.servers = servers
        Current.webhooks = webhooks
        // Without a vendor identifier no registration counts as another device's, so every fake
        // server accepts the registration update.
        Current.device.identifierForVendor = { nil }
        webhooks.sendEphemeralHandler = { [recorder] server, request in
            if request.type == "update_registration" {
                recorder?.updatedServers.append(server.identifier)
            }
            return ["webhook_id": "webhook-id"]
        }
    }

    override func tearDown() {
        Current.device.identifierForVendor = previousVendorID
        Current.webhooks = previousWebhooks
        Current.servers = previousServers
        super.tearDown()
    }

    private func makeRegistry(stored: String?) -> LiveActivityRegistry {
        recorder.storedToken = stored
        let store = LiveActivityPushToStartTokenStore(
            read: { [recorder] in recorder?.storedToken },
            write: { [recorder] in recorder?.storedToken = $0 }
        )
        return LiveActivityRegistry(pushToStartTokenStore: store)
    }

    private var allServerIdentifiers: Set<Identifier<Server>> {
        Set(servers.all.map(\.identifier))
    }

    // MARK: - Keychain store

    /// The app's store and the registration payload read the same Keychain entry. Writing nil removes
    /// the entry, which is a no-op in the entitlement-less test host.
    func testKeychainStore_matchesRegistrationGetter() {
        LiveActivityPushToStartTokenStore.keychain.write(nil)
        XCTAssertEqual(LiveActivityPushToStartTokenStore.keychain.read(), LiveActivityRegistry.storedPushToStartToken)
    }

    // MARK: - hexString

    func testHexString_isLowercaseAndZeroPadded() {
        XCTAssertEqual(LiveActivityRegistry.hexString(Data([0x00, 0x0A, 0xFF, 0x10])), "000aff10")
    }

    func testHexString_emptyData_isEmpty() {
        XCTAssertEqual(LiveActivityRegistry.hexString(Data()), "")
    }

    // MARK: - pushToStartTokenToSync

    func testPushToStartTokenToSync_nilCurrent_keepsStored() {
        XCTAssertNil(LiveActivityRegistry.pushToStartTokenToSync(current: nil, stored: "0a0b"))
        XCTAssertNil(LiveActivityRegistry.pushToStartTokenToSync(current: nil, stored: nil))
    }

    func testPushToStartTokenToSync_emptyCurrent_keepsStored() {
        XCTAssertNil(LiveActivityRegistry.pushToStartTokenToSync(current: Data(), stored: "0a0b"))
    }

    func testPushToStartTokenToSync_unchangedToken_isNil() {
        XCTAssertNil(LiveActivityRegistry.pushToStartTokenToSync(current: Data([0x0A, 0x0B]), stored: "0a0b"))
    }

    func testPushToStartTokenToSync_rotatedToken_returnsNewHex() {
        XCTAssertEqual(
            LiveActivityRegistry.pushToStartTokenToSync(current: Data([0x0A, 0x0B]), stored: "ffee"),
            "0a0b"
        )
    }

    func testPushToStartTokenToSync_nothingStored_returnsHex() {
        XCTAssertEqual(
            LiveActivityRegistry.pushToStartTokenToSync(current: Data([0x0A, 0x0B]), stored: nil),
            "0a0b"
        )
    }

    // MARK: - syncPushToStartToken

    func testSyncPushToStartToken_rotatedToken_storesAndReportsToEveryServer() async {
        let registry = makeRegistry(stored: "ffee")

        await registry.syncPushToStartToken(current: Data([0x01, 0xAB]))

        XCTAssertEqual(recorder.storedToken, "01ab")
        XCTAssertEqual(recorder.updatedServers.count, 2)
        XCTAssertEqual(Set(recorder.updatedServers), allServerIdentifiers)
    }

    func testSyncPushToStartToken_nothingStored_storesAndReportsToEveryServer() async {
        let registry = makeRegistry(stored: nil)

        await registry.syncPushToStartToken(current: Data([0x01, 0xAB]))

        XCTAssertEqual(recorder.storedToken, "01ab")
        XCTAssertEqual(recorder.updatedServers.count, 2)
        XCTAssertEqual(Set(recorder.updatedServers), allServerIdentifiers)
    }

    func testSyncPushToStartToken_unchangedToken_doesNotReport() async {
        let registry = makeRegistry(stored: "01ab")

        await registry.syncPushToStartToken(current: Data([0x01, 0xAB]))

        XCTAssertEqual(recorder.storedToken, "01ab")
        XCTAssertEqual(recorder.updatedServers, [])
    }

    func testSyncPushToStartToken_nilCurrent_keepsStoredTokenAndDoesNotReport() async {
        let registry = makeRegistry(stored: "01ab")

        await registry.syncPushToStartToken(current: nil)

        XCTAssertEqual(recorder.storedToken, "01ab")
        XCTAssertEqual(recorder.updatedServers, [])
    }

    func testSyncPushToStartToken_emptyCurrent_keepsStoredTokenAndDoesNotReport() async {
        let registry = makeRegistry(stored: "01ab")

        await registry.syncPushToStartToken(current: Data())

        XCTAssertEqual(recorder.storedToken, "01ab")
        XCTAssertEqual(recorder.updatedServers, [])
    }

    /// `reattach()` runs the sync with ActivityKit's live value, which the simulator never issues, so
    /// a stored token must survive it untouched and nothing is reported.
    func testReattach_withoutSystemToken_keepsStoredTokenAndDoesNotReport() async {
        let registry = makeRegistry(stored: "01ab")

        await registry.reattach()

        XCTAssertEqual(recorder.storedToken, "01ab")
        XCTAssertEqual(recorder.updatedServers, [])
    }
}
#endif

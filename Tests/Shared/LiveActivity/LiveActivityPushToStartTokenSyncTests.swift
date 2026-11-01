#if canImport(ActivityKit)
import Foundation
@testable import Shared
import XCTest

/// The push-to-start token stream only delivers tokens issued while the app observes it. These tests
/// cover the reconciliation that catches a token the system rotated while the app was not running
/// (home-assistant/iOS#5812), so the stale one stops being re-sent to Core on every registration.
@available(iOS 17.2, *)
final class LiveActivityPushToStartTokenSyncTests: XCTestCase {
    /// In-memory stand-in for the Keychain, which the test host cannot access.
    private final class StoredToken: @unchecked Sendable {
        var value: String?
        init(_ value: String?) { self.value = value }
    }

    private var previousServers: ServerManager!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        Current.servers = FakeServerManager(initial: 0)
    }

    override func tearDown() {
        Current.servers = previousServers
        super.tearDown()
    }

    private func makeRegistry(stored: String?) -> (LiveActivityRegistry, StoredToken) {
        let token = StoredToken(stored)
        let store = LiveActivityPushToStartTokenStore(read: { token.value }, write: { token.value = $0 })
        return (LiveActivityRegistry(pushToStartTokenStore: store), token)
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

    func testSyncPushToStartToken_rotatedToken_replacesStoredToken() async {
        let (registry, stored) = makeRegistry(stored: "ffee")

        await registry.syncPushToStartToken(current: Data([0x01, 0xAB]))

        XCTAssertEqual(stored.value, "01ab")
    }

    func testSyncPushToStartToken_nothingStored_storesCurrentToken() async {
        let (registry, stored) = makeRegistry(stored: nil)

        await registry.syncPushToStartToken(current: Data([0x01, 0xAB]))

        XCTAssertEqual(stored.value, "01ab")
    }

    func testSyncPushToStartToken_unchangedToken_leavesStoredToken() async {
        let (registry, stored) = makeRegistry(stored: "01ab")

        await registry.syncPushToStartToken(current: Data([0x01, 0xAB]))

        XCTAssertEqual(stored.value, "01ab")
    }

    func testSyncPushToStartToken_nilCurrent_keepsStoredToken() async {
        let (registry, stored) = makeRegistry(stored: "01ab")

        await registry.syncPushToStartToken(current: nil)

        XCTAssertEqual(stored.value, "01ab")
    }

    /// `reattach()` runs the sync with ActivityKit's live value, which the simulator never issues, so
    /// a stored token must survive it untouched.
    func testReattach_withoutSystemToken_keepsStoredToken() async {
        let (registry, stored) = makeRegistry(stored: "01ab")

        await registry.reattach()

        XCTAssertEqual(stored.value, "01ab")
    }
}
#endif

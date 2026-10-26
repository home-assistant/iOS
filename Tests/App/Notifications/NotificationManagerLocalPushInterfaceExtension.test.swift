@testable import HomeAssistant
import NetworkExtension
@testable import Shared
import XCTest

final class NotificationManagerLocalPushInterfaceExtensionTests: XCTestCase {
    private var servers: FakeServerManager!
    private var originalServers: ServerManager!

    override func setUp() {
        super.setUp()
        originalServers = Current.servers
        servers = FakeServerManager(initial: 0)
        Current.servers = servers
    }

    override func tearDown() {
        Current.servers = originalServers
        super.tearDown()
    }

    private enum TestError: Error {
        case loadFailed
    }

    private func makeLocalPushServer() -> Server {
        let server = servers.addFake()
        server.update { info in
            info.connection.isLocalPushEnabled = true
            info.connection.internalSSIDs = ["Home"]
            info.connection.set(address: URL(string: "http://homeassistant.local:8123"), for: .internal)
        }
        return server
    }

    private func wait(seconds: TimeInterval) {
        let settled = expectation(description: "wait \(seconds)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { settled.fulfill() }
        wait(for: [settled], timeout: seconds + 10)
    }

    private func waitUntil(
        timeout: TimeInterval = 30,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping () -> Bool
    ) {
        let met = expectation(for: NSPredicate { _, _ in condition() }, evaluatedWith: nil)
        wait(for: [met], timeout: timeout)
        XCTAssertTrue(condition(), "condition not met within \(timeout)s", file: file, line: line)
    }

    private func assertDisabled(
        _ status: NotificationManagerLocalPushStatus,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .disabled = status else {
            return XCTFail("expected disabled status without an active push manager", file: file, line: line)
        }
    }

    private func makeStaleManager() -> NEAppPushManager {
        let stale = NEAppPushManager()
        stale.matchSSIDs = ["Old"]
        return stale
    }

    private func makeSavedManager(for server: Server) throws -> NEAppPushManager {
        let configuration = [PushProviderConfiguration(
            serverIdentifier: server.identifier,
            settingsKey: PushProviderConfiguration.defaultSettingsKey(for: server)
        )]
        let manager = NEAppPushManager()
        manager.isEnabled = true
        manager.localizedDescription = "HomeAssistant for Home"
        manager.providerBundleIdentifier = AppConstants.BundleID + ".PushProvider"
        manager.matchSSIDs = ["Home"]
        manager.providerConfiguration = try [
            PushProviderConfiguration.providerConfigurationKey: JSONEncoder().encode(configuration),
        ]
        return manager
    }

    func testLoadFailureFinishesTheUpdateSoTheNextOneRuns() {
        let server = makeLocalPushServer()
        var loads = 0
        let interface = NotificationManagerLocalPushInterfaceExtension(loadManagers: { completion in
            loads += 1
            completion(nil, TestError.loadFailed)
        })

        interface.serversDidChange(servers)
        interface.serversDidChange(servers)
        wait(seconds: 0.5)

        XCTAssertEqual(loads, 2)
        assertDisabled(interface.status(for: server))
    }

    func testMatchingSavedConfigurationIsNotSavedAgain() throws {
        let server = makeLocalPushServer()
        let saved = try makeSavedManager(for: server)
        var loads = 0
        let interface = NotificationManagerLocalPushInterfaceExtension(loadManagers: { completion in
            loads += 1
            completion([saved], nil)
        })

        interface.serversDidChange(servers)
        wait(seconds: 1)

        XCTAssertEqual(loads, 2)
        assertDisabled(interface.status(for: server))
    }

    func testReloadFailureAfterSaveFinishesTheUpdate() {
        let server = makeLocalPushServer()
        var loads = 0
        let interface = NotificationManagerLocalPushInterfaceExtension(loadManagers: { completion in
            loads += 1
            if loads.isMultiple(of: 2) {
                completion(nil, TestError.loadFailed)
            } else {
                completion([], nil)
            }
        })

        interface.serversDidChange(servers)
        wait(seconds: 2)

        XCTAssertEqual(loads, 4)
        assertDisabled(interface.status(for: server))
    }

    func testReloadAfterSaveConfiguresTheSavedManager() throws {
        let server = makeLocalPushServer()
        let saved = try makeSavedManager(for: server)
        var loads = 0
        let interface = NotificationManagerLocalPushInterfaceExtension(loadManagers: { completion in
            loads += 1
            completion(loads == 1 ? [] : [saved], nil)
        })

        waitUntil { loads == 2 }

        XCTAssertEqual(loads, 2)
        assertDisabled(interface.status(for: server))
    }

    func testUnmatchedSavedManagerIsRemovedBeforeTheUpdateFinishes() {
        let server = makeLocalPushServer()
        var loads = 0
        let interface =
            NotificationManagerLocalPushInterfaceExtension(loadManagers: { [stale = makeStaleManager()] completion in
                loads += 1
                completion([stale], nil)
            })

        waitUntil { loads == 2 }

        XCTAssertEqual(loads, 2)
        assertDisabled(interface.status(for: server))
    }

    func testRetryOnMatchingNetworkRecreatesAnInactiveManager() throws {
        let server = makeLocalPushServer()
        let saved = try makeSavedManager(for: server)
        let originalNetworkState = Current.connectivity.currentNetworkState
        defer { Current.connectivity.currentNetworkState = originalNetworkState }
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "Home") }

        var loads = 0
        let interface = NotificationManagerLocalPushInterfaceExtension(loadManagers: { completion in
            loads += 1
            completion([saved], nil)
        })
        wait(seconds: 0.5)
        XCTAssertEqual(loads, 1)

        interface.retryLocalPush(for: server, reason: .manual)
        waitUntil { loads == 3 }

        XCTAssertEqual(loads, 3)
        assertDisabled(interface.status(for: server))
    }

    func testRetryAwayFromTheNetworkKeepsTheSavedManager() throws {
        let server = makeLocalPushServer()
        let saved = try makeSavedManager(for: server)
        let originalNetworkState = Current.connectivity.currentNetworkState
        defer { Current.connectivity.currentNetworkState = originalNetworkState }
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "Away") }

        var loads = 0
        let interface = NotificationManagerLocalPushInterfaceExtension(loadManagers: { completion in
            loads += 1
            completion([saved], nil)
        })
        wait(seconds: 0.5)

        interface.retryLocalPush(for: server, reason: .manual)
        wait(seconds: 1)

        XCTAssertEqual(loads, 1)
        assertDisabled(interface.status(for: server))
    }

    func testOverlappingUpdatesCoalesceAndStatusIsDisabledWithoutActiveManager() {
        let server = makeLocalPushServer()

        let interface = NotificationManagerLocalPushInterfaceExtension()
        interface.serversDidChange(servers)
        interface.serversDidChange(servers)
        let offMain = expectation(description: "server change from a background queue")
        DispatchQueue.global().async {
            interface.serversDidChange(self.servers)
            offMain.fulfill()
        }
        wait(for: [offMain], timeout: 10)

        var observed = [NotificationManagerLocalPushStatus]()
        let token = interface.addObserver(for: server) { observed.append($0) }
        defer { token.cancel() }

        let settled = expectation(description: "manager updates settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { settled.fulfill() }
        wait(for: [settled], timeout: 10)

        interface.retryLocalPush(for: server, reason: .manual)
        interface.scheduleAppOpenLocalPushRetries()

        let drained = expectation(description: "retry tasks run")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { drained.fulfill() }
        wait(for: [drained], timeout: 10)

        assertDisabled(interface.status(for: server))
        for status in observed {
            assertDisabled(status)
        }
    }
}

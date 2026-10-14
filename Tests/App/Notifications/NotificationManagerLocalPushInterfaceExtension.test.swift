@testable import HomeAssistant
import NetworkExtension
@testable import Shared
import XCTest

final class NotificationManagerLocalPushInterfaceExtensionTests: XCTestCase {
    private var servers: FakeServerManager!

    override func setUp() {
        super.setUp()
        servers = FakeServerManager(initial: 0)
        Current.servers = servers
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

    private func assertDisabled(
        _ status: NotificationManagerLocalPushStatus,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .disabled = status else {
            return XCTFail("expected disabled status without an active push manager", file: file, line: line)
        }
    }

    private func makeSettledInterface() -> NotificationManagerLocalPushInterfaceExtension {
        let interface = NotificationManagerLocalPushInterfaceExtension()
        wait(seconds: 1.5)
        return interface
    }

    func testLoadFailureFinishesTheUpdateSoTheNextOneRuns() {
        let server = makeLocalPushServer()
        let interface = makeSettledInterface()
        var loads = 0
        interface.loadManagers = { completion in
            loads += 1
            completion(nil, TestError.loadFailed)
        }

        interface.serversDidChange(servers)
        interface.serversDidChange(servers)
        wait(seconds: 0.5)

        XCTAssertEqual(loads, 2)
        assertDisabled(interface.status(for: server))
    }

    func testMatchingSavedConfigurationIsNotSavedAgain() throws {
        let server = makeLocalPushServer()
        let configuration = [PushProviderConfiguration(
            serverIdentifier: server.identifier,
            settingsKey: PushProviderConfiguration.defaultSettingsKey(for: server)
        )]
        let encoded = try JSONEncoder().encode(configuration)
        let interface = makeSettledInterface()
        var loads = 0
        interface.loadManagers = { completion in
            loads += 1
            let manager = NEAppPushManager()
            manager.isEnabled = true
            manager.localizedDescription = "HomeAssistant for Home"
            manager.providerBundleIdentifier = AppConstants.BundleID + ".PushProvider"
            manager.matchSSIDs = ["Home"]
            manager.providerConfiguration = [PushProviderConfiguration.providerConfigurationKey: encoded]
            completion([manager], nil)
        }

        interface.serversDidChange(servers)
        wait(seconds: 1)

        XCTAssertEqual(loads, 1)
        assertDisabled(interface.status(for: server))
    }

    func testReloadFailureAfterSaveFinishesTheUpdate() {
        let server = makeLocalPushServer()
        let interface = makeSettledInterface()
        var loads = 0
        interface.loadManagers = { completion in
            loads += 1
            if loads == 1 {
                completion([], nil)
            } else {
                completion(nil, TestError.loadFailed)
            }
        }

        interface.serversDidChange(servers)
        wait(seconds: 1.5)

        XCTAssertEqual(loads, 2)
        assertDisabled(interface.status(for: server))
    }

    func testOverlappingUpdatesCoalesceAndStatusIsDisabledWithoutActiveManager() {
        let server = makeLocalPushServer()

        let interface = NotificationManagerLocalPushInterfaceExtension()
        interface.serversDidChange(servers)
        interface.serversDidChange(servers)

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

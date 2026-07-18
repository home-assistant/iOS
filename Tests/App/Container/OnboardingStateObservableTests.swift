@testable import HomeAssistant
@testable import Shared
import XCTest

@MainActor
final class OnboardingStateObservableTests: XCTestCase {
    private var previousServers: ServerManager!
    private var firstServer: Server!
    private var secondServer: Server!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        let servers = FakeServerManager(initial: 0)
        firstServer = servers.add(identifier: .init(rawValue: "server-1"), serverInfo: .fake())
        secondServer = servers.add(identifier: .init(rawValue: "server-2"), serverInfo: .fake())
        Current.servers = servers

        resetPersistedState()
    }

    override func tearDown() {
        Current.servers = previousServers
        resetPersistedState()
        super.tearDown()
    }

    private func resetPersistedState() {
        Current.settingsStore.restoreLastURL = true
        Current.settingsStore.lastActiveServerIdentifier = nil
        Current.settingsStore.lastActiveURLPath = nil
    }

    func testPreferredInitialServerReturnsPersistedServerWhenPresent() {
        Current.settingsStore.lastActiveServerIdentifier = "server-2"

        XCTAssertEqual(OnboardingStateObservable.preferredInitialServer()?.identifier, secondServer.identifier)
    }

    func testPreferredInitialServerFallsBackToFirstWhenNoneStored() {
        Current.settingsStore.lastActiveServerIdentifier = nil

        XCTAssertEqual(OnboardingStateObservable.preferredInitialServer()?.identifier, firstServer.identifier)
    }

    func testPreferredInitialServerFallsBackToFirstWhenStoredServerMissing() {
        Current.settingsStore.lastActiveServerIdentifier = "server-removed"

        XCTAssertEqual(OnboardingStateObservable.preferredInitialServer()?.identifier, firstServer.identifier)
    }

    func testRestoredInitialPathReturnsStoredPathForMatchingServerWhenEnabled() {
        Current.settingsStore.restoreLastURL = true
        Current.settingsStore.lastActiveServerIdentifier = "server-2"
        Current.settingsStore.lastActiveURLPath = "/lovelace/kitchen"

        XCTAssertEqual(OnboardingStateObservable.restoredInitialPath(for: secondServer), "/lovelace/kitchen")
    }

    func testRestoredInitialPathIsNilWhenRememberLastPageOff() {
        Current.settingsStore.restoreLastURL = false
        Current.settingsStore.lastActiveServerIdentifier = "server-2"
        Current.settingsStore.lastActiveURLPath = "/lovelace/kitchen"

        XCTAssertNil(OnboardingStateObservable.restoredInitialPath(for: secondServer))
    }

    func testRestoredInitialPathIsNilWhenServerDoesNotMatchStored() {
        // Launch fell back to the first server after the saved one was removed: it must not inherit the
        // path that belonged to the removed server.
        Current.settingsStore.restoreLastURL = true
        Current.settingsStore.lastActiveServerIdentifier = "server-2"
        Current.settingsStore.lastActiveURLPath = "/lovelace/kitchen"

        XCTAssertNil(OnboardingStateObservable.restoredInitialPath(for: firstServer))
    }
}

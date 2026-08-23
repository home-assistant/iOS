import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

@MainActor
final class OnboardingStateObservableTests: XCTestCase {
    private var previousServers: ServerManager!
    private var servers: FakeServerManager!
    private var firstServer: Server!
    private var secondServer: Server!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        servers = FakeServerManager(initial: 0)
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

    func testShowWebViewPersistsLastActiveServerIdentifier() {
        Current.settingsStore.lastActiveServerIdentifier = "server-1"
        Current.settingsStore.lastActiveURLPath = "/lovelace/kitchen"
        let sut = OnboardingStateObservable()

        sut.showWebView(for: secondServer)

        XCTAssertEqual(Current.settingsStore.lastActiveServerIdentifier, "server-2")
        XCTAssertNil(Current.settingsStore.lastActiveURLPath)
        XCTAssertEqual(sut.screen, .webView(secondServer, initialPath: nil))
    }

    func testOnboardingCompleteRestoresLastUsedServerNotFirstInList() {
        Current.settingsStore.lastActiveServerIdentifier = "server-2"
        Current.settingsStore.lastActiveURLPath = "/lovelace/office"
        let sut = OnboardingStateObservable()

        sut.onboardingStateDidChange(to: .complete)

        waitUntil { sut.screen == .webView(secondServer, initialPath: "/lovelace/office") }
        XCTAssertEqual(sut.screen, .webView(secondServer, initialPath: "/lovelace/office"))
    }

    func testLogoutFallsBackToLastUsedRemainingServer() {
        Current.settingsStore.lastActiveServerIdentifier = "server-2"
        let sut = OnboardingStateObservable()

        sut.onboardingStateDidChange(to: .needed(.logout))

        waitUntil { sut.screen == .webView(secondServer, initialPath: nil) }
        XCTAssertEqual(sut.screen, .webView(secondServer, initialPath: nil))
    }

    func testOnboardingCompleteFallsBackWhenLastUsedServerWasRemoved() {
        Current.settingsStore.lastActiveServerIdentifier = "server-2"
        let sut = OnboardingStateObservable()
        servers.remove(identifier: secondServer.identifier)

        sut.onboardingStateDidChange(to: .complete)

        waitUntil { sut.screen == .webView(firstServer, initialPath: nil) }
        XCTAssertEqual(sut.screen, .webView(firstServer, initialPath: nil))
    }

    func testPreferredInitialServerPrefersKioskServerWhenEnabled() throws {
        try withKiosk(enabled: true, serverId: "server-2") {
            Current.settingsStore.lastActiveServerIdentifier = "server-1"

            XCTAssertEqual(OnboardingStateObservable.preferredInitialServer()?.identifier, secondServer.identifier)
        }
    }

    func testOnboardingCompletePrefersKioskServerOverLastUsed() throws {
        try withKiosk(enabled: true, serverId: "server-2") {
            Current.settingsStore.lastActiveServerIdentifier = "server-1"
            let sut = OnboardingStateObservable()

            sut.onboardingStateDidChange(to: .complete)

            waitUntil { sut.screen == .webView(secondServer, initialPath: nil) }
            XCTAssertEqual(sut.screen, .webView(secondServer, initialPath: nil))
        }
    }

    private func withKiosk(enabled: Bool, serverId: String, _ body: () throws -> Void) throws {
        let previousDatabase = Current.database
        let previousKiosk = Current.kiosk
        defer {
            Current.database = previousDatabase
            Current.kiosk = previousKiosk
        }

        let database = try DatabaseQueue(path: ":memory:")
        try KioskSettingsTable().createIfNeeded(database: database)
        Current.database = { database }
        try database.write { db in
            try KioskSettings(enabled: enabled, serverId: serverId).insert(db, onConflict: .replace)
        }
        Current.kiosk = KioskModeManager()

        try body()
    }

    private func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = expectation(description: "condition")
        let deadline = Date().addingTimeInterval(timeout)

        func poll() {
            if condition() {
                expectation.fulfill()
            } else if Date() > deadline {
                XCTFail("Timed out waiting for condition", file: file, line: line)
                expectation.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { poll() }
            }
        }

        poll()
        wait(for: [expectation], timeout: timeout + 1)
    }
}

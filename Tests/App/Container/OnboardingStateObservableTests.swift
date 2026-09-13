@testable import HomeAssistant
@testable import Shared
import UIKit
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

    // MARK: - Frontend theme mode

    func testTheServerOnScreenIsWhatDecidesTheAppsAppearance() {
        Current.settingsStore.lastActiveServerIdentifier = "server-1"
        let themeMode = ThemeModeProbe()
        themeMode.remember("dark", for: firstServer)
        themeMode.remember("light", for: secondServer)

        // Launching straight into a server reads that server's preference.
        let state = OnboardingStateObservable(themeMode: themeMode.observer)
        XCTAssertEqual(themeMode.styles, [.dark])

        // Switching server reads the new one's.
        state.showWebView(for: secondServer)
        XCTAssertEqual(themeMode.styles.last, .light)
    }

    func testLaunchingIntoOnboardingLeavesTheDeviceInCharge() {
        Current.servers = FakeServerManager(initial: 0)
        let themeMode = ThemeModeProbe()

        _ = OnboardingStateObservable(themeMode: themeMode.observer)

        // No server means nobody whose preference to follow, so nothing is overridden.
        XCTAssertEqual(themeMode.styles, [])
    }

    /// A real observer on a scratch defaults suite, recording the styles it would have applied.
    @MainActor
    private final class ThemeModeProbe {
        private(set) var styles: [UIUserInterfaceStyle] = []
        let observer: FrontendThemeModeObserver

        private let defaults: UserDefaults
        private let suiteName: String

        init() {
            let suiteName = "OnboardingStateObservableTests-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            self.suiteName = suiteName
            self.defaults = defaults
            // The observer needs somewhere to report to before `self` is available to report to.
            var record: (@MainActor (UIUserInterfaceStyle) -> Void)?
            self.observer = FrontendThemeModeObserver(defaults: defaults, applyStyle: { record?($0) })
            record = { [weak self] in self?.styles.append($0) }
        }

        deinit {
            defaults.removePersistentDomain(forName: suiteName)
        }

        func remember(_ mode: String, for server: Server) {
            defaults.set(mode, forKey: "frontendThemeMode-\(server.identifier.rawValue)")
        }
    }
}

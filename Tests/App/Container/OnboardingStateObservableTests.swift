import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import UIKit
import XCTest

@MainActor
final class OnboardingStateObservableTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousApis: [Identifier<Server>: HomeAssistantAPI]!
    private var firstServer: Server!
    private var secondServer: Server!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        previousApis = Current.cachedApis
        let servers = FakeServerManager(initial: 0)
        firstServer = servers.add(identifier: .init(rawValue: "server-1"), serverInfo: .fake())
        secondServer = servers.add(identifier: .init(rawValue: "server-2"), serverInfo: .fake())
        Current.servers = servers
        // Mocked, so observing a server does not open a websocket to `ServerInfo.fake()`'s URL.
        Current.cachedApis = [firstServer, secondServer].reduce(into: [:]) { apis, server in
            let api = HomeAssistantAPI(server: server)
            api.connection = HAMockConnection()
            apis[server.identifier] = api
        }

        resetPersistedState()
    }

    override func tearDown() {
        Current.servers = previousServers
        Current.cachedApis = previousApis
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

    // MARK: - Recovered server re-authentication

    private final class ReauthProbe {
        var loginDetails: OnboardingAuthDetails?
        var importRequested = false
        var fetchedCertificate: ClientCertificate?
        var result: Swift.Result<Void, Error>?
    }

    private let importedCertificate = ClientCertificate(keychainIdentifier: "imported", displayName: "Imported")
    private let storedCertificate = ClientCertificate(keychainIdentifier: "stored", displayName: "Stored")
    private let newToken = TokenInfo(accessToken: "new-access", refreshToken: "new-refresh", expiration: .distantFuture)

    private func reauthenticate(
        server: Server,
        requiresCertificate: Promise<Bool> = .value(false),
        importResult: Promise<ClientCertificate>,
        loginResult: Promise<OnboardingAuthLoginResult> = .value(.init(code: "code", resolvedURL: nil))
    ) -> ReauthProbe {
        let probe = ReauthProbe()
        let token = newToken
        let state = OnboardingStateObservable()
        state.reauthenticator.clientCertificateRequirement = { _ in requiresCertificate }
        state.reauthenticator.fetchToken = { _, _, _, certificate in
            probe.fetchedCertificate = certificate
            return .value(token)
        }
        let completed = expectation(description: "completion")
        state.performRecoveredServerReauthentication(
            for: server,
            using: .external,
            login: { details in
                probe.loginDetails = details
                return loginResult
            },
            importClientCertificate: {
                probe.importRequested = true
                return importResult
            },
            completion: { result in
                probe.result = result
                completed.fulfill()
            }
        )
        wait(for: [completed], timeout: 5)
        if case .success = probe.result {
            XCTAssertEqual(state.screen, .webView(server, initialPath: nil))
        }
        return probe
    }

    func testRecoveredServerReauthAsksForACertificateWhenTheServerRequiresOne() {
        let probe = reauthenticate(
            server: firstServer,
            requiresCertificate: .value(true),
            importResult: .value(importedCertificate)
        )

        XCTAssertTrue(probe.importRequested)
        XCTAssertEqual(probe.loginDetails?.clientCertificate, importedCertificate)
        XCTAssertEqual(probe.fetchedCertificate, importedCertificate)
        XCTAssertEqual(firstServer.info.token, newToken)
        XCTAssertEqual(firstServer.info.connection.clientCertificate, importedCertificate)
    }

    func testRecoveredServerReauthLogsInDirectlyWhenTheServerDoesNotRequireACertificate() {
        let probe = reauthenticate(
            server: firstServer,
            requiresCertificate: .value(false),
            importResult: .value(importedCertificate)
        )

        XCTAssertFalse(probe.importRequested)
        XCTAssertNil(probe.loginDetails?.clientCertificate)
        XCTAssertEqual(firstServer.info.token, newToken)
        XCTAssertNil(firstServer.info.connection.clientCertificate)
    }

    func testRecoveredServerReauthKeepsTheCertificateTheServerAlreadyHas() {
        firstServer.update { $0.connection.clientCertificate = storedCertificate }

        let probe = reauthenticate(
            server: firstServer,
            requiresCertificate: Promise(error: ProbeError.unexpected),
            importResult: .value(importedCertificate)
        )

        XCTAssertFalse(probe.importRequested)
        XCTAssertEqual(probe.loginDetails?.clientCertificate, storedCertificate)
        XCTAssertEqual(firstServer.info.connection.clientCertificate, storedCertificate)
    }

    func testRecoveredServerReauthReportsCancellationWhenTheCertificateImportIsCancelled() {
        let probe = reauthenticate(
            server: firstServer,
            requiresCertificate: .value(true),
            importResult: Promise(error: PMKError.cancelled)
        )

        XCTAssertNil(probe.loginDetails)
        guard case let .failure(error) = probe.result else {
            return XCTFail("expected a failure")
        }
        XCTAssertEqual(error as? RecoveredServerReauthenticationError, .cancelled)
        XCTAssertNotEqual(firstServer.info.token, newToken)
    }

    func testRecoveredServerReauthFailsWhenTheCertificateProbeFails() {
        let probe = reauthenticate(
            server: firstServer,
            requiresCertificate: Promise(error: ProbeError.unexpected),
            importResult: .value(importedCertificate)
        )

        XCTAssertNil(probe.loginDetails)
        guard case let .failure(error) = probe.result else {
            return XCTFail("expected a failure")
        }
        XCTAssertEqual(error as? ProbeError, .unexpected)
    }

    private enum ProbeError: Error, Equatable {
        case unexpected
    }

    // MARK: - Frontend theme mode

    func testTheServerOnScreenIsWhatDecidesTheAppsAppearance() {
        Current.settingsStore.lastActiveServerIdentifier = "server-1"
        let themeMode = ThemeModeProbe()
        themeMode.remember("dark", for: firstServer)
        themeMode.remember("light", for: secondServer)

        // Launching straight into a server reads that server's preference.
        let state = OnboardingStateObservable(themeMode: themeMode.observer)
        XCTAssertEqual(themeMode.mode(for: firstServer), .dark)

        // Switching server reads the new one's.
        state.showWebView(for: secondServer)
        XCTAssertEqual(themeMode.mode(for: secondServer), .light)
    }

    func testLaunchingIntoOnboardingLeavesTheDeviceInCharge() {
        Current.servers = FakeServerManager(initial: 0)
        let themeMode = ThemeModeProbe()

        _ = OnboardingStateObservable(themeMode: themeMode.observer)

        // No server means nobody whose preference to follow, so nothing is overridden.
        XCTAssertEqual(themeMode.mode(for: firstServer), .automatic)
    }

    /// A real observer on a scratch defaults suite, reporting to an applier that styles no windows.
    @MainActor
    private final class ThemeModeProbe {
        let observer: FrontendThemeModeObserver

        private let applier = FrontendThemeModeApplier(windowScenes: { [] })
        private let defaults: UserDefaults
        private let suiteName: String

        init() {
            let suiteName = "OnboardingStateObservableTests-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            self.suiteName = suiteName
            self.defaults = defaults
            self.observer = FrontendThemeModeObserver(defaults: defaults, applier: applier)
        }

        deinit {
            defaults.removePersistentDomain(forName: suiteName)
        }

        func mode(for server: Server) -> FrontendThemeMode {
            applier.mode(for: server.identifier)
        }

        func remember(_ mode: String, for server: Server) {
            defaults.set(mode, forKey: "frontendThemeMode-\(server.identifier.rawValue)")
        }
    }
}

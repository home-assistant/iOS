import Foundation
import GRDB
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// How the top-level screen follows onboarding events and kiosk settings after launch: a removed or
/// logged-out server falls back to another one (or onboarding), completing onboarding opens the web
/// view, and turning kiosk mode on for another server switches to it.
///
/// `.sharedState`: the observable reads `Current.servers`, the kiosk settings and the settings store
/// from main-queue callbacks, and the tests swap them globally.
@Suite(.sharedState)
@MainActor
struct OnboardingStateObservableTransitionsTests {
    private func withServers(
        _ count: Int,
        _ body: (FakeServerManager, DatabaseQueue) async throws -> Void
    ) async throws {
        // Kiosk mode writes sensor allowlists and migration state, and the observable records the last
        // active server, all in `Current.settingsStore.prefs`: give them a store only this test writes.
        let settings = PrivateSettingsStore()
        let previousServers = Current.servers
        let previousApis = Current.cachedApis
        let previousDatabase = Current.database
        let previousKiosk = Current.kiosk
        let previousSensors = Current.sensors
        defer {
            Current.servers = previousServers
            Current.cachedApis = previousApis
            Current.database = previousDatabase
            Current.kiosk = previousKiosk
            Current.sensors = previousSensors
            settings.restore()
        }
        let servers = FakeServerManager(initial: 0)
        for index in 0 ..< count {
            _ = servers.add(identifier: .init(rawValue: "server-\(index)"), serverInfo: .fake())
        }
        Current.servers = servers
        // Mocked, so observing a server does not open a websocket to `ServerInfo.fake()`'s URL.
        Current.cachedApis = servers.all.reduce(into: [:]) { apis, server in
            let api = HomeAssistantAPI(server: server)
            api.connection = HAMockConnection()
            apis[server.identifier] = api
        }
        Current.settingsStore.lastActiveServerIdentifier = nil
        let database = try SettingsTestDatabase.make()
        Current.database = { database }
        // Turning kiosk mode on switches its sensors on, which signals every observer of the sensor
        // container; each API registered with the app's container answers with a full sensor update.
        Current.sensors = SensorContainer()
        Current.kiosk = KioskModeManager()
        try await body(servers, database)
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    @Test func aRemovedServerFallsBackToAnotherOne() async throws {
        try await withServers(2) { servers, _ in
            let observable = OnboardingStateObservable()
            observable.showWebView(for: servers.all[1])

            observable.onboardingStateDidChange(to: .needed(.error))
            await #expect(waitUntil { observable.screen == .webView(servers.all[0], initialPath: nil) })

            // Re-authentication is the web view's job; the screen stays.
            observable.onboardingStateDidChange(to: .needed(.unauthenticated("server-0", 401)))
            observable.onboardingStateDidChange(to: .didConnect)
            observable.showWebView(for: servers.all[1])
            observable.onboardingStateDidChange(to: .complete)
            await #expect(waitUntil { observable.screen == .webView(servers.all[0], initialPath: nil) })
        }
    }

    @Test func losingTheLastServerRestartsOnboarding() async throws {
        try await withServers(1) { servers, _ in
            let observable = OnboardingStateObservable()
            servers.removeAll()
            observable.onboardingStateDidChange(to: .needed(.logout))
            await #expect(waitUntil { observable.screen == .onboarding(.initial) })

            // Completing without a server leaves onboarding up.
            observable.onboardingStateDidChange(to: .complete)
            #expect(observable.screen == .onboarding(.initial))
        }
    }

    @Test func turningOnKioskModeSwitchesToItsServer() async throws {
        try await withServers(2) { servers, database in
            let observable = OnboardingStateObservable()
            #expect(observable.screen == .webView(servers.all[0], initialPath: nil))

            try await database.write { db in
                try KioskSettings(enabled: true, serverId: "server-1").insert(db, onConflict: .replace)
            }
            await #expect(waitUntil { observable.screen == .webView(servers.all[1], initialPath: nil) })

            // A dashboard change on the same server navigates in place.
            try await database.write { db in
                try KioskSettings(enabled: true, serverId: "server-1", dashboard: "kiosk-view")
                    .insert(db, onConflict: .replace)
            }
            try await database.write { db in
                try KioskSettings(enabled: false, serverId: "server-1").insert(db, onConflict: .replace)
            }
            #expect(observable.screen == .webView(servers.all[1], initialPath: nil))
        }
    }

    @Test func theRecoveredServerImportReevaluatesLater() async throws {
        try await withServers(1) { _, _ in
            let observable = OnboardingStateObservable()
            observable.completeRecoveredServerImport()
            observable.reevaluate()
            #expect(
                RecoveredServerReauthenticationError.cancelled.errorDescription
                    == L10n.Onboarding.ServerImport.Reauthenticate.errorsCancelled
            )
        }
    }
}

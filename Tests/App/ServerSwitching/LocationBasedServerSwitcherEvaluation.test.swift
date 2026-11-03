import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// One activation's evaluation end to end: the Wi-Fi network the device is on picks the server whose
/// home it belongs to, the match is cached for the server picker, recorded as a client event and
/// applied once per visit; with switching off, in kiosk mode or with a single server nothing runs.
///
/// `.sharedState`: the evaluation runs in a task that reads `Current.servers`, the connectivity
/// wrapper and the settings store, and the match is cached in the app group defaults.
@Suite(.sharedState)
@MainActor
struct LocationBasedServerSwitcherEvaluationTests {
    /// Where `ServerPriority` caches the closest server.
    private static let closestServerKey = "closestServerIdentifier"

    private func withWorld(
        kiosk: KioskSettings = KioskSettings(),
        _ body: (Server, Server, MockClientEventStore) async throws -> Void
    ) async throws {
        let previousServers = Current.servers
        let previousDatabase = Current.database
        let previousKiosk = Current.kiosk
        let previousEvents = Current.clientEventStore
        let previousNetworkState = Current.connectivity.currentNetworkState
        let previousSwitching = Current.settingsStore.locationBasedServerSwitching
        let previousLastActive = Current.settingsStore.lastActiveServerIdentifier
        let previousClosest = ServerPriority.cachedClosestServer
        defer {
            Current.servers = previousServers
            Current.database = previousDatabase
            Current.kiosk = previousKiosk
            Current.clientEventStore = previousEvents
            Current.connectivity.currentNetworkState = previousNetworkState
            Current.settingsStore.locationBasedServerSwitching = previousSwitching
            Current.settingsStore.lastActiveServerIdentifier = previousLastActive
            if let previousClosest {
                ServerPriority.cacheClosestServer(previousClosest)
            } else {
                UserDefaults(suiteName: AppConstants.AppGroupID)?.removeObject(forKey: Self.closestServerKey)
            }
        }

        let database = try SettingsTestDatabase.make()
        try await database.write { db in try kiosk.insert(db, onConflict: .replace) }
        Current.database = { database }
        Current.kiosk = KioskModeManager()

        let servers = FakeServerManager(initial: 1)
        var secondHome = ServerInfo.fake()
        secondHome.remoteName = "Second Home"
        secondHome.connection.internalSSIDs = ["SecondHomeWiFi"]
        let first = servers.all[0]
        let second = servers.add(identifier: .init(rawValue: "second-home"), serverInfo: secondHome)
        Current.servers = servers

        let events = MockClientEventStore(addEventAction: { _ in })
        Current.clientEventStore = events
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "SecondHomeWiFi") }
        Current.settingsStore.locationBasedServerSwitching = true
        Current.settingsStore.lastActiveServerIdentifier = first.identifier.rawValue

        try await body(first, second, events)
    }

    /// The switches recorded; other work for the fake servers (a failed state fetch) logs events too.
    private func switches(in events: MockClientEventStore) -> [ClientEvent] {
        events.addedEvents.filter { $0.text.hasPrefix("Switched server based on location") }
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    private func waitUntilIdle(_ switcher: LocationBasedServerSwitcher) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while switcher.isEvaluating {
            if Date() > deadline { return false }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    @Test func theHomeNetworkSwitchesToItsServerOncePerVisit() async throws {
        // The switch goes through the app-wide coordinator; a mock keeps the host app on its own screen.
        let previousCoordinator = Current.sceneManager.appCoordinator.value
        let coordinator = MockAppCoordinator()
        Current.sceneManager.registerAppCoordinator(coordinator)
        defer {
            if let previousCoordinator {
                Current.sceneManager.registerAppCoordinator(previousCoordinator)
            }
        }

        try await withWorld { _, second, events in
            let switcher = LocationBasedServerSwitcher()
            switcher.applicationStateGetter = { .active }
            switcher.start()
            switcher.start()

            switcher.evaluate()
            #expect(switcher.isEvaluating)
            // A second activation while the first is still running is ignored.
            switcher.evaluate()
            await #expect(waitUntilIdle(switcher))

            #expect(ServerPriority.cachedClosestServer == second.identifier)
            #expect(switches(in: events).count == 1)
            #expect(switches(in: events).first?.text.contains("Second Home") == true)
            await #expect(waitUntil { coordinator.openedServers.map(\.identifier) == [second.identifier] })

            // Same home, same visit: nothing new to announce.
            switcher.evaluate()
            await #expect(waitUntilIdle(switcher))
            #expect(switches(in: events).count == 1)
        }
    }

    @Test func kioskModeKeepsItsServer() async throws {
        try await withWorld(kiosk: KioskSettings(enabled: true)) { _, _, events in
            let switcher = LocationBasedServerSwitcher()
            switcher.evaluate()
            #expect(!switcher.isEvaluating)
            #expect(switches(in: events).isEmpty)
        }
    }

    @Test func nothingRunsWithSwitchingOff() async throws {
        try await withWorld { _, _, events in
            Current.settingsStore.locationBasedServerSwitching = false
            let switcher = LocationBasedServerSwitcher()
            switcher.evaluate()
            #expect(!switcher.isEvaluating)
            #expect(switches(in: events).isEmpty)
        }
    }

    @Test func noNetworkAndNoLocationLeavesTheServerAlone() async throws {
        try await withWorld { first, _, events in
            Current.connectivity.currentNetworkState = { NetworkState() }
            let switcher = LocationBasedServerSwitcher()
            switcher.evaluate()
            await #expect(waitUntilIdle(switcher))
            #expect(switches(in: events).isEmpty)
            #expect(Current.settingsStore.lastActiveServerIdentifier == first.identifier.rawValue)
        }
    }
}

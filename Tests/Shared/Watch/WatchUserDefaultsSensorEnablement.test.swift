import Foundation
@testable import Shared
import Testing

// Serialized: the tests replace the shared `Current.servers`, which concurrent tests would race on.
@Suite(.serialized)
struct WatchUserDefaultsSensorEnablementTests {
    private static let suiteName = "WatchUserDefaultsSensorEnablementTests"

    private let defaults: UserDefaults
    private let servers = FakeServerManager(initial: 2)

    init() throws {
        self.defaults = try #require(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)
    }

    /// Runs `body` with the fake servers installed as the app's, restoring the real ones afterwards.
    private func withServers<T>(_ body: (WatchUserDefaults) throws -> T) rethrows -> T {
        let original = Current.servers
        defer { Current.servers = original }
        Current.servers = servers
        return try body(WatchUserDefaults(userDefaults: defaults))
    }

    @Test func choicesAreKeptPerServer() {
        let (first, second) = (servers.all[0].identifier, servers.all[1].identifier)

        withServers { watchDefaults in
            watchDefaults.setSensorEnabled(true, uniqueID: "battery_level", forServer: first)

            #expect(watchDefaults.enabledSensorIDs(forServer: first) == ["battery_level"])
            #expect(watchDefaults.isSensorEnabled(uniqueID: "battery_level", forServer: first))
            #expect(watchDefaults.enabledSensorIDs(forServer: second).isEmpty)
            #expect(watchDefaults.isSensorEnabled(uniqueID: "battery_level", forServer: second) == false)
        }
    }

    @Test func aSelectionMadeBeforeServersWereSeparateGoesToTheServersTheWatchHas() {
        defaults.set(["battery_state"], forKey: WatchUserDefaultsKey.enabledSensorIDs.rawValue)
        let (first, second) = (servers.all[0].identifier, servers.all[1].identifier)

        withServers { watchDefaults in
            watchDefaults.splitSensorEnablementAcrossServersIfNeeded()

            #expect(watchDefaults.enabledSensorIDs(forServer: first) == ["battery_state"])
            #expect(watchDefaults.enabledSensorIDs(forServer: second) == ["battery_state"])
        }
        #expect(defaults.object(forKey: WatchUserDefaultsKey.enabledSensorIDs.rawValue) == nil)
    }

    @Test func aSyncDropsTheChoicesOfServersTheIPhoneNoLongerHas() {
        let (first, second) = (servers.all[0].identifier, servers.all[1].identifier)

        withServers { watchDefaults in
            watchDefaults.setSensorEnabled(true, uniqueID: "battery_level", forServer: first)
            watchDefaults.setSensorEnabled(true, uniqueID: "battery_level", forServer: second)

            watchDefaults.applySyncedServersToSensorEnablement([first])

            #expect(watchDefaults.enabledSensorIDs(forServer: first) == ["battery_level"])
            #expect(watchDefaults.enabledSensorIDs(forServer: second).isEmpty)
        }
    }
}

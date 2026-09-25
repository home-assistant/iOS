import Foundation
@testable import Shared
import Testing

// Serialized: every test works on the same defaults suite, which each one starts from empty.
@Suite(.serialized)
struct WatchSensorEnablementStoreTests {
    private static let suiteName = "WatchSensorEnablementStoreTests"

    private let defaults: UserDefaults
    private let serverA = Server.fake()
    private let serverB = Server.fake()

    init() throws {
        self.defaults = try #require(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)
    }

    private func makeStore(servers: [Server]) -> WatchSensorEnablementStore {
        WatchSensorEnablementStore(defaults: defaults, servers: { servers })
    }

    /// Puts the defaults into the state an install that predates per-server enablement left them in:
    /// one list of switched-on sensors shared by every server.
    private func seedSharedSelection(_ uniqueIDs: [String]) {
        defaults.set(uniqueIDs, forKey: WatchUserDefaultsKey.enabledSensorIDs.rawValue)
    }

    private var storedByServer: [String: [String]] {
        defaults.object(forKey: WatchUserDefaultsKey.enabledSensorIDsByServer.rawValue) as? [String: [String]] ?? [:]
    }

    private var sharedSelectionRemains: Bool {
        defaults.object(forKey: WatchUserDefaultsKey.enabledSensorIDs.rawValue) != nil
    }

    @Test func aFreshInstallStartsWithNothingEnabled() {
        let store = makeStore(servers: [serverA])

        #expect(store.enabledSensorIDs(forServer: serverA.identifier).isEmpty)
        #expect(store.isSensorEnabled(uniqueID: "battery_level", forServer: serverA.identifier) == false)
        #expect(!sharedSelectionRemains)
    }

    @Test func switchingOnIsRecordedForThatServerAlone() {
        let store = makeStore(servers: [serverA, serverB])

        store.setSensorEnabled(true, uniqueID: "battery_level", forServer: serverA.identifier)

        #expect(store.enabledSensorIDs(forServer: serverA.identifier) == ["battery_level"])
        #expect(store.isSensorEnabled(uniqueID: "battery_level", forServer: serverA.identifier))
        #expect(store.enabledSensorIDs(forServer: serverB.identifier).isEmpty)
        #expect(store.isSensorEnabled(uniqueID: "battery_level", forServer: serverB.identifier) == false)
    }

    @Test func switchingOffRemovesItForThatServerAlone() {
        let store = makeStore(servers: [serverA, serverB])
        store.setSensorEnabled(true, uniqueID: "battery_level", forServer: serverA.identifier)
        store.setSensorEnabled(true, uniqueID: "battery_level", forServer: serverB.identifier)

        store.setSensorEnabled(false, uniqueID: "battery_level", forServer: serverA.identifier)

        #expect(store.enabledSensorIDs(forServer: serverA.identifier).isEmpty)
        #expect(store.enabledSensorIDs(forServer: serverB.identifier) == ["battery_level"])
    }

    @Test func choicesSurviveANewStoreOverTheSameDefaults() {
        makeStore(servers: [serverA]).setSensorEnabled(true, uniqueID: "battery_state", forServer: serverA.identifier)

        let reopened = makeStore(servers: [serverA])

        #expect(reopened.enabledSensorIDs(forServer: serverA.identifier) == ["battery_state"])
        #expect(storedByServer == [serverA.identifier.rawValue: ["battery_state"]])
    }

    @Test func theSharedSelectionIsHandedToEveryServerTheWatchHas() {
        seedSharedSelection(["battery_state", "battery_level"])
        let store = makeStore(servers: [serverA, serverB])

        #expect(store.enabledSensorIDs(forServer: serverA.identifier) == ["battery_level", "battery_state"])
        #expect(store.enabledSensorIDs(forServer: serverB.identifier) == ["battery_level", "battery_state"])
        #expect(!sharedSelectionRemains)
        #expect(defaults.bool(forKey: WatchUserDefaultsKey.enabledSensorIDsSplitAcrossServers.rawValue))
    }

    @Test func aServerAddedAfterTheSplitStartsWithNothingEnabled() {
        seedSharedSelection(["battery_level"])
        // The split runs on this read, while the watch only has one server.
        #expect(makeStore(servers: [serverA]).enabledSensorIDs(forServer: serverA.identifier) == ["battery_level"])

        let later = makeStore(servers: [serverA, serverB])

        #expect(later.enabledSensorIDs(forServer: serverA.identifier) == ["battery_level"])
        #expect(later.enabledSensorIDs(forServer: serverB.identifier).isEmpty)
    }

    @Test func theSplitWaitsUntilTheWatchHasServers() {
        seedSharedSelection(["battery_level"])

        // Nothing to hand the selection to yet: it is kept for when the servers arrive.
        #expect(makeStore(servers: []).enabledSensorIDs(forServer: serverA.identifier).isEmpty)
        #expect(sharedSelectionRemains)
        #expect(storedByServer.isEmpty)

        #expect(makeStore(servers: [serverA]).enabledSensorIDs(forServer: serverA.identifier) == ["battery_level"])
        #expect(!sharedSelectionRemains)
    }

    @Test func anEmptySharedSelectionStillCompletesTheSplit() {
        seedSharedSelection([])
        let store = makeStore(servers: [serverA])

        #expect(store.enabledSensorIDs(forServer: serverA.identifier).isEmpty)
        #expect(!sharedSelectionRemains)
        #expect(defaults.bool(forKey: WatchUserDefaultsKey.enabledSensorIDsSplitAcrossServers.rawValue))
    }

    @Test func forgettingServersDropsTheirChoicesAndKeepsTheRest() {
        let store = makeStore(servers: [serverA, serverB])
        store.setSensorEnabled(true, uniqueID: "battery_level", forServer: serverA.identifier)
        store.setSensorEnabled(true, uniqueID: "battery_state", forServer: serverB.identifier)

        store.forgetServers(otherThan: [serverA.identifier])

        #expect(store.enabledSensorIDs(forServer: serverA.identifier) == ["battery_level"])
        #expect(store.enabledSensorIDs(forServer: serverB.identifier).isEmpty)
        #expect(storedByServer.keys.sorted() == [serverA.identifier.rawValue])
    }

    @Test func forgettingServersLeavesAPendingSplitAlone() {
        seedSharedSelection(["battery_level"])
        let store = makeStore(servers: [])

        store.forgetServers(otherThan: [])

        #expect(sharedSelectionRemains)
        #expect(makeStore(servers: [serverA]).enabledSensorIDs(forServer: serverA.identifier) == ["battery_level"])
    }
}

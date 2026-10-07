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
        defaults.set(uniqueIDs, forKey: WatchSensorEnablementStore.Key.legacyEnabled)
    }

    private var storedByServer: [String: [String]] {
        defaults.object(forKey: WatchSensorEnablementStore.Key.enabledByServer) as? [String: [String]] ?? [:]
    }

    private var sharedSelectionRemains: Bool {
        defaults.object(forKey: WatchSensorEnablementStore.Key.legacyEnabled) != nil
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
        #expect(defaults.bool(forKey: WatchSensorEnablementStore.Key.splitAcrossServers))
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
        #expect(defaults.bool(forKey: WatchSensorEnablementStore.Key.splitAcrossServers))
    }

    @Test func splittingAtLaunchHandsTheSelectionToTheServersTheWatchHasThen() {
        seedSharedSelection(["battery_level"])

        makeStore(servers: [serverA]).splitAcrossServersIfNeeded()

        let afterSync = makeStore(servers: [serverA, serverB])
        #expect(afterSync.enabledSensorIDs(forServer: serverA.identifier) == ["battery_level"])
        #expect(afterSync.enabledSensorIDs(forServer: serverB.identifier).isEmpty)
        #expect(!sharedSelectionRemains)
    }

    @Test func splittingAtLaunchWithoutServersKeepsTheSelectionForLater() {
        seedSharedSelection(["battery_level"])

        makeStore(servers: []).splitAcrossServersIfNeeded()

        #expect(sharedSelectionRemains)
        #expect(storedByServer.isEmpty)
    }

    @Test func aSyncDropsTheChoicesOfServersItLeftOut() {
        let store = makeStore(servers: [serverA, serverB])
        store.setSensorEnabled(true, uniqueID: "battery_level", forServer: serverA.identifier)
        store.setSensorEnabled(true, uniqueID: "battery_state", forServer: serverB.identifier)

        store.applySyncedServers([serverA.identifier])

        #expect(store.enabledSensorIDs(forServer: serverA.identifier) == ["battery_level"])
        #expect(store.enabledSensorIDs(forServer: serverB.identifier).isEmpty)
        #expect(storedByServer.keys.sorted() == [serverA.identifier.rawValue])
    }

    @Test func aSyncThatKeepsEveryServerChangesNothing() {
        let store = makeStore(servers: [serverA])
        store.setSensorEnabled(true, uniqueID: "battery_level", forServer: serverA.identifier)

        store.applySyncedServers([serverA.identifier])

        #expect(storedByServer == [serverA.identifier.rawValue: ["battery_level"]])
    }

    @Test func aSyncFinishesAPendingSplitWithTheServersItRestored() {
        seedSharedSelection(["battery_level"])
        // Nothing read the store before the sync, so the split is still pending when it lands.
        let store = makeStore(servers: [serverA])

        store.applySyncedServers([serverA.identifier])

        #expect(store.enabledSensorIDs(forServer: serverA.identifier) == ["battery_level"])
        #expect(!sharedSelectionRemains)
        #expect(makeStore(servers: [serverA, serverB]).enabledSensorIDs(forServer: serverB.identifier).isEmpty)
    }

    @Test func aSyncThatLeavesNoServersDropsAPendingSelection() {
        seedSharedSelection(["battery_level"])
        let store = makeStore(servers: [])

        store.applySyncedServers([])

        // The iPhone has no servers, so the selection belongs to nobody: a server it adds later
        // starts opt-in rather than inheriting choices made for servers that are gone.
        #expect(!sharedSelectionRemains)
        #expect(defaults.bool(forKey: WatchSensorEnablementStore.Key.splitAcrossServers))
        #expect(makeStore(servers: [serverB]).enabledSensorIDs(forServer: serverB.identifier).isEmpty)
    }
}

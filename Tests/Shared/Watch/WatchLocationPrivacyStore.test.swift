import Foundation
@testable import Shared
import Testing

// Serialized: every test works on the same defaults suite, which each one starts from empty.
@Suite(.serialized)
struct WatchLocationPrivacyStoreTests {
    private static let suiteName = "WatchLocationPrivacyStoreTests"

    private let defaults: UserDefaults
    private let serverA = Server.fake()
    private let serverB = Server.fake()

    init() throws {
        self.defaults = try #require(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)
    }

    @Test func aServerReceivesNoLocationUntilTheUserChooses() {
        let store = WatchLocationPrivacyStore(defaults: defaults)

        #expect(store.locationPrivacy(forServer: serverA.identifier) == .never)
    }

    @Test func eachServerKeepsItsOwnChoice() {
        let store = WatchLocationPrivacyStore(defaults: defaults)

        store.setLocationPrivacy(.exact, forServer: serverA.identifier)
        store.setLocationPrivacy(.zoneOnly, forServer: serverB.identifier)

        #expect(store.locationPrivacy(forServer: serverA.identifier) == .exact)
        #expect(store.locationPrivacy(forServer: serverB.identifier) == .zoneOnly)
        // Persisted, not just held in memory.
        #expect(WatchLocationPrivacyStore(defaults: defaults).locationPrivacy(forServer: serverA.identifier) == .exact)
    }

    @Test func choosingNeverForgetsTheChoice() {
        let store = WatchLocationPrivacyStore(defaults: defaults)
        store.setLocationPrivacy(.exact, forServer: serverA.identifier)

        store.setLocationPrivacy(.never, forServer: serverA.identifier)

        #expect(store.locationPrivacy(forServer: serverA.identifier) == .never)
        #expect(defaults.dictionary(forKey: WatchLocationPrivacyStore.Key.privacyByServer)?.isEmpty == true)
    }

    @Test func aServerTheSyncLeftOutStartsOverWhenItComesBack() {
        let store = WatchLocationPrivacyStore(defaults: defaults)
        store.setLocationPrivacy(.exact, forServer: serverA.identifier)
        store.setLocationPrivacy(.zoneOnly, forServer: serverB.identifier)

        store.applySyncedServers([serverB.identifier])

        #expect(store.locationPrivacy(forServer: serverA.identifier) == .never)
        #expect(store.locationPrivacy(forServer: serverB.identifier) == .zoneOnly)
    }
}

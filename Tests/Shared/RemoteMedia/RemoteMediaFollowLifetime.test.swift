import Foundation
@testable import Shared
import Testing

/// A Follow relationship's identity and its place in the order they were created.
///
/// The order is the load-bearing half. Registration is asynchronous and can outlive the process
/// that started it, so the server has to be able to recognise a registration that describes a
/// relationship the user has already replaced — and a UUID gives it nothing to work with.
@Suite(.serialized)
struct RemoteMediaFollowLifetimeTests {
    private let selection = RemoteMediaSelection(serverId: "home", entityId: "media_player.speaker")
    private let other = RemoteMediaSelection(serverId: "home", entityId: "media_player.tv")

    /// Restores everything this suite writes, so it cannot disturb the user's own state or another
    /// suite's.
    private func withStore(_ body: (SettingsStore) throws -> Void) rethrows {
        let store = Current.settingsStore
        let lifetime = store.remoteMediaFollowLifetime
        let sequence = store.remoteMediaFollowSequence
        let selection = store.remoteMediaSelection
        defer {
            store.remoteMediaFollowLifetime = lifetime
            store.remoteMediaFollowSequence = sequence
            store.remoteMediaSelection = selection
        }
        try body(store)
    }

    @Test func aRelationshipPersistsUntilFollowingChanges() throws {
        try withStore { store in
            let lifetime = try #require(store.startRemoteMediaFollowLifetime(following: selection))
            #expect(!lifetime.generation.isEmpty)
            #expect(lifetime.sequence > 0)
            // Reading it again, and from another store over the same defaults, is the same one.
            #expect(store.remoteMediaFollowLifetime == lifetime)
            #expect(SettingsStore().remoteMediaFollowLifetime == lifetime)
        }
    }

    /// Re-following the same player produces the same session identifier, so the relationship is
    /// the only thing that distinguishes the new one from the old — and the sequence is the only
    /// thing that says which is which.
    @Test func followingAgainStartsALaterRelationship() throws {
        try withStore { store in
            let first = try #require(store.startRemoteMediaFollowLifetime(following: selection))
            let second = try #require(store.startRemoteMediaFollowLifetime(following: selection))
            #expect(first.generation != second.generation)
            #expect(second.sequence == first.sequence + 1)
        }
    }

    @Test func switchingPlayersStartsALaterRelationship() throws {
        try withStore { store in
            let first = try #require(store.startRemoteMediaFollowLifetime(following: selection))
            let second = try #require(store.startRemoteMediaFollowLifetime(following: other))
            #expect(second.sequence > first.sequence)
        }
    }

    @Test func stoppingEndsTheRelationshipWithoutSpendingASequence() throws {
        try withStore { store in
            let first = try #require(store.startRemoteMediaFollowLifetime(following: selection))
            #expect(store.startRemoteMediaFollowLifetime(following: nil) == nil)
            #expect(store.remoteMediaFollowLifetime == nil)
            // Stopping is not a relationship, so it does not consume a value; the next Follow is
            // still strictly later than the one that just ended.
            #expect(store.remoteMediaFollowSequence == first.sequence)
            let next = try #require(store.startRemoteMediaFollowLifetime(following: selection))
            #expect(next.sequence == first.sequence + 1)
        }
    }

    /// The counter survives the app being killed, which is the whole point of it: an in-memory
    /// value would restart at 1 and make a brand new relationship look older than the last.
    @Test func theSequenceSurvivesARelaunch() throws {
        try withStore { store in
            let first = try #require(store.startRemoteMediaFollowLifetime(following: selection))
            // A new store over the same defaults is what a relaunch looks like from here.
            let relaunched = SettingsStore()
            let second = try #require(relaunched.startRemoteMediaFollowLifetime(following: selection))
            #expect(second.sequence == first.sequence + 1)
        }
    }

    // MARK: - Bounds

    /// The clamp has to happen before the addition: computing the successor of `Int.max` first
    /// and capping it afterwards traps on exactly the input the cap exists for. This test caught
    /// that as a process crash rather than a failure.
    @Test func theSequenceStaysRepresentable() {
        #expect(RemoteMediaFollowLifetime.nextSequence(after: 0) == 1)
        #expect(RemoteMediaFollowLifetime.nextSequence(after: 41) == 42)
        // A JSON number in the push relay is a double, so anything past 2^53 - 1 would reach the
        // phone rounded.
        #expect(RemoteMediaFollowLifetime.maximumSequence == 9_007_199_254_740_991)
        #expect(
            RemoteMediaFollowLifetime.nextSequence(after: .max)
                == RemoteMediaFollowLifetime.maximumSequence
        )
        #expect(
            RemoteMediaFollowLifetime.nextSequence(
                after: RemoteMediaFollowLifetime.maximumSequence
            ) == RemoteMediaFollowLifetime.maximumSequence
        )
    }

    /// A corrupted or hand-edited negative must not make the next relationship look older.
    @Test func aNonsenseStoredValueStillProducesAForwardStep() {
        #expect(RemoteMediaFollowLifetime.nextSequence(after: -5) == 1)
        #expect(RemoteMediaFollowLifetime.nextSequence(after: .min) == 1)
    }

    @Test func theSequenceReadBackIsNeverNegative() throws {
        try withStore { store in
            store.remoteMediaFollowSequence = -3
            #expect(store.remoteMediaFollowSequence == 0)
            let lifetime = try #require(store.startRemoteMediaFollowLifetime(following: selection))
            #expect(lifetime.sequence == 1)
        }
    }

    // MARK: - Migration

    /// A development install can hold a relationship from before there was an order to be in.
    /// Adopting it costs one counter step and keeps the user's followed player working.
    @Test func anUnorderedRelationshipFromAnEarlierBuildIsAdopted() throws {
        try withStore { store in
            store.remoteMediaFollowLifetime = nil
            store.remoteMediaSelection = selection
            store.prefs.set("legacy-uuid", forKey: "remoteMediaSessionGeneration")

            let migrated = try #require(store.migrateRemoteMediaFollowLifetime())
            #expect(migrated.generation == "legacy-uuid")
            #expect(migrated.sequence > 0)
            #expect(store.remoteMediaFollowLifetime == migrated)
            // Migrating once is enough; the old key is gone.
            #expect(store.prefs.string(forKey: "remoteMediaSessionGeneration") == nil)
        }
    }

    @Test func migrationLeavesACurrentRelationshipAlone() throws {
        try withStore { store in
            let current = try #require(store.startRemoteMediaFollowLifetime(following: selection))
            store.prefs.set("legacy-uuid", forKey: "remoteMediaSessionGeneration")
            #expect(store.migrateRemoteMediaFollowLifetime() == current)
            #expect(store.remoteMediaFollowLifetime == current)
        }
    }

    @Test func migrationInventsNothingWhenNoPlayerIsFollowed() throws {
        try withStore { store in
            store.remoteMediaFollowLifetime = nil
            store.remoteMediaSelection = nil
            store.prefs.set("legacy-uuid", forKey: "remoteMediaSessionGeneration")
            #expect(store.migrateRemoteMediaFollowLifetime() == nil)
            #expect(store.remoteMediaFollowLifetime == nil)
        }
    }
}

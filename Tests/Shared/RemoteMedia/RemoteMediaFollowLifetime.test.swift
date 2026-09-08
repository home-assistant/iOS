@testable import Shared
import Testing

/// A Follow relationship's identity and its place in the order they were created.
///
/// The order is the load-bearing half. Registration is asynchronous and can outlive the process
/// that started it, so the server has to be able to recognise a registration that describes a
/// relationship the user has already replaced — and a UUID gives it nothing to work with.
struct RemoteMediaFollowLifetimeTests {
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
}

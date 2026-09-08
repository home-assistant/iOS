#if !targetEnvironment(macCatalyst)
import HAKit
@testable import HomeAssistant
@testable import Shared
import Testing

/// The suite itself carries no `@available`: swift-testing refuses to apply `@Test` to a function
/// marked unavailable, so each test checks at runtime, like the other version-gated suites here.
@MainActor
struct RemoteMediaSessionPublisherTests {
    @available(iOS 27.0, *)
    private final class Driver: RemoteMediaSessionDriver {
        var snapshots: [RemoteMediaSnapshot?] = []
        var duringPublish: (() -> Void)?
        var shouldFail = false

        func publish(_ snapshot: RemoteMediaSnapshot?) async throws {
            snapshots.append(snapshot)
            duringPublish?()
            if shouldFail { throw RemoteMediaError.unavailable }
        }
    }

    private func snapshot(state: String = "playing", title: String = "Track") throws -> RemoteMediaSnapshot {
        let entity = try HAEntity(
            entityId: "media_player.speaker", state: state,
            lastChanged: .distantPast, lastUpdated: .distantPast,
            attributes: ["media_title": title],
            context: .init(id: "test", userId: nil, parentId: nil)
        )
        return try #require(RemoteMediaSnapshotMapper.map(entity, serverId: "home")).snapshot
    }

    @Test func playTrackChangePauseAndStop() async throws {
        guard #available(iOS 27.0, *) else { return }
        let driver = Driver()
        let publisher = RemoteMediaSessionPublisher(driver: driver)
        let playing = try snapshot()
        let next = try snapshot(title: "Next")
        let paused = try snapshot(state: "paused", title: "Next")
        for value in [playing, next, paused] {
            publisher.publish(value)
            await publisher.waitForPendingUpdates()
        }
        publisher.publish(nil)
        await publisher.waitForPendingUpdates()
        #expect(driver.snapshots == [playing, next, paused, nil])
    }

    /// "Follow in Now Playing" means follow until the user stops following. Integrations pass
    /// through `idle` between tracks and drop to `unavailable` and back, so an inactive state with
    /// media still to show keeps its card — only `nil`, the selection no longer being followed,
    /// ends the session. The publisher forwards what the reducer decided rather than second-
    /// guessing it.
    @Test(arguments: ["idle", "off", "unavailable", "unknown"])
    func anInactiveStateStillPublishesItsCard(state: String) async throws {
        guard #available(iOS 27.0, *) else { return }
        let driver = Driver()
        let publisher = RemoteMediaSessionPublisher(driver: driver)
        let inactive = try snapshot(state: state)
        publisher.publish(inactive)
        await publisher.waitForPendingUpdates()
        #expect(driver.snapshots == [inactive])
    }

    @Test func onlyNoLongerFollowingEndsTheSession() async throws {
        guard #available(iOS 27.0, *) else { return }
        let driver = Driver()
        let publisher = RemoteMediaSessionPublisher(driver: driver)
        publisher.publish(nil)
        await publisher.waitForPendingUpdates()
        #expect(driver.snapshots == [nil])
    }

    @Test func stopArrivingDuringStartIsNotLost() async throws {
        guard #available(iOS 27.0, *) else { return }
        let driver = Driver()
        let publisher = RemoteMediaSessionPublisher(driver: driver)
        driver.duringPublish = {
            driver.duringPublish = nil
            publisher.publish(nil)
        }
        try publisher.publish(snapshot())
        await publisher.waitForPendingUpdates()
        #expect(driver.snapshots.count == 2)
        #expect(driver.snapshots[0] != nil)
        #expect(driver.snapshots[1] == nil)
    }

    @Test func failureAllowsLaterUpdate() async throws {
        guard #available(iOS 27.0, *) else { return }
        let driver = Driver()
        let publisher = RemoteMediaSessionPublisher(driver: driver)
        var hadError = false
        publisher.onError = { hadError = $0 != nil }
        driver.shouldFail = true
        try publisher.publish(snapshot())
        await publisher.waitForPendingUpdates()
        #expect(hadError)
        driver.shouldFail = false
        try publisher.publish(snapshot(state: "paused"))
        await publisher.waitForPendingUpdates()
        #expect(!hadError)
        #expect(driver.snapshots.count == 2)
    }
}
#endif

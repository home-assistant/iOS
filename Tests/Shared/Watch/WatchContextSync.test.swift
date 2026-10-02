import Foundation
@testable import Shared
import Testing

struct WatchContextSync_test {
    /// Counts the syncs a `WatchContextSyncQueue` performs and can be told to fail them.
    private final class RecordingSync: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        private let performed = DispatchSemaphore(value: 0)

        var error: Error?

        var performCount: Int {
            lock.lock(); defer { lock.unlock() }
            return count
        }

        func perform(_ context: HAWatchConnectivity.Context) throws {
            lock.lock()
            count += 1
            lock.unlock()
            performed.signal()
            if let error { throw error }
        }

        func waitForPerform() -> Bool {
            performed.wait(timeout: .now() + 5) == .success
        }
    }

    private struct SyncFailed: LocalizedError {
        var errorDescription: String? { "sync failed" }
    }

    @Test func awaitedSyncSkipsWithoutAWatch() async {
        let fake = RecordingSync()
        let queue = WatchContextSyncQueue(label: "test", perform: fake.perform)

        let error = await HomeAssistantAPI.syncWatchContextAndWait(hasWatch: false, on: queue)

        #expect(error == nil)
        #expect(fake.performCount == 0)
    }

    @Test func awaitedSyncReportsSuccess() async {
        let fake = RecordingSync()
        let queue = WatchContextSyncQueue(label: "test", perform: fake.perform)

        let error = await HomeAssistantAPI.syncWatchContextAndWait(hasWatch: true, on: queue)

        #expect(error == nil)
        #expect(fake.performCount == 1)
    }

    @Test func awaitedSyncReportsTheQueueError() async {
        let fake = RecordingSync()
        fake.error = SyncFailed()
        let queue = WatchContextSyncQueue(label: "test", perform: fake.perform)

        let error = await HomeAssistantAPI.syncWatchContextAndWait(hasWatch: true, on: queue)

        #expect(error?.localizedDescription == "sync failed")
    }

    @Test func backgroundSyncEnqueuesOnce() async {
        let fake = RecordingSync()
        let queue = WatchContextSyncQueue(label: "test", perform: fake.perform)

        await HomeAssistantAPI.syncWatchContextInBackground(hasWatch: true, on: queue)

        #expect(fake.waitForPerform())
        #expect(fake.performCount == 1)
    }

    @Test func backgroundSyncSkipsWithoutAWatch() async {
        let fake = RecordingSync()
        let queue = WatchContextSyncQueue(label: "test", perform: fake.perform)

        await HomeAssistantAPI.syncWatchContextInBackground(hasWatch: false, on: queue)

        #expect(fake.performCount == 0)
    }

    @Test func reloadReportsSuccess() async {
        let fake = RecordingSync()
        let queue = WatchContextSyncQueue(label: "test", perform: fake.perform)

        let outcome = await HomeAssistantAPI.reloadWatchComplications(on: queue)

        #expect(outcome == .success)
        #expect(fake.performCount == 1)
    }

    @Test func reloadReportsTheQueueError() async {
        let fake = RecordingSync()
        fake.error = SyncFailed()
        let queue = WatchContextSyncQueue(label: "test", perform: fake.perform)

        let outcome = await HomeAssistantAPI.reloadWatchComplications(on: queue)

        #expect(outcome == .failed("sync failed"))
    }

    @Test func sharedQueueReportsTheSessionError() async {
        // The test host has no activated session with a paired counterpart, so the real sync must
        // come back with an error rather than hang the caller.
        let error = await HomeAssistantAPI.syncWatchContextAndWait(
            hasWatch: true,
            on: HomeAssistantAPI.watchContextSyncQueue
        )

        #expect(error != nil)
    }

    @Test func entryPointsDoNothingWithoutAPairedWatch() async {
        let error = await HomeAssistantAPI.SyncWatchContext()
        #expect(error == nil)

        HomeAssistantAPI.syncWatchContext()

        #if os(iOS)
        let outcome = await HomeAssistantAPI.reloadWatchComplications()
        #expect(outcome == .watchUnavailable)
        #endif
    }
}

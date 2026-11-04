import Foundation
@testable import Shared
import Testing

struct WatchContextSyncQueue_test {
    /// Stand-in for the blocking `updateApplicationContext` call: records what it was handed and can
    /// be told to stall until released, like a wedged WCSession.
    private final class FakeContextSync: @unchecked Sendable {
        private let lock = NSLock()
        private var syncedIdentifiers: [String] = []
        private let release = DispatchSemaphore(value: 0)
        private let started = DispatchSemaphore(value: 0)

        var stalls = false
        var error: Error?

        var synced: [String] {
            lock.lock(); defer { lock.unlock() }
            return syncedIdentifiers
        }

        func perform(_ context: HAWatchConnectivity.Context) throws {
            lock.lock()
            syncedIdentifiers.append(context.content["id"] as? String ?? "")
            lock.unlock()
            started.signal()
            if stalls {
                release.wait()
            }
            if let error { throw error }
        }

        /// Blocks until `perform` has been entered.
        func waitUntilStarted() {
            _ = started.wait(timeout: .now() + 5)
        }

        /// Lets one stalled `perform` return.
        func releaseOne() {
            release.signal()
        }
    }

    private struct SyncFailed: Error {}

    /// Records every value handed to it, with the thread it arrived on.
    private final class ValueBox<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: T?
        private var onMainStorage = false
        private var countStorage = 0

        func set(_ value: T, onMain: Bool = Thread.isMainThread) {
            lock.lock()
            stored = value
            onMainStorage = onMain
            countStorage += 1
            lock.unlock()
        }

        var value: T? {
            lock.lock(); defer { lock.unlock() }
            return stored
        }

        var wasOnMain: Bool {
            lock.lock(); defer { lock.unlock() }
            return onMainStorage
        }

        var count: Int {
            lock.lock(); defer { lock.unlock() }
            return countStorage
        }
    }

    private static func context(_ id: String) -> HAWatchConnectivity.Context {
        HAWatchConnectivity.Context(content: ["id": id])
    }

    @Test func enqueueRunsTheSyncOffTheCallerAndCompletes() {
        let fake = FakeContextSync()
        let queue = WatchContextSyncQueue(label: "test", perform: fake.perform)
        let done = DispatchSemaphore(value: 0)
        let completion = ValueBox<Error?>()

        queue.enqueue(Self.context("a")) { error in
            completion.set(error)
            done.signal()
        }

        #expect(done.wait(timeout: .now() + 5) == .success)
        #expect(fake.synced == ["a"])
        #expect(completion.value! == nil)
        #expect(completion.wasOnMain == false)
    }

    @Test func contextsArrivingWhileStalledCoalesceToTheNewest() {
        let fake = FakeContextSync()
        fake.stalls = true
        let queue = WatchContextSyncQueue(label: "test", perform: fake.perform)
        let completions = ValueBox<String>()
        let done = DispatchSemaphore(value: 0)

        queue.enqueue(Self.context("a")) { _ in completions.set("a"); done.signal() }
        fake.waitUntilStarted()
        // Both arrive while "a" is stuck: "b" is superseded by "c" and never sent.
        queue.enqueue(Self.context("b")) { _ in completions.set("b"); done.signal() }
        queue.enqueue(Self.context("c")) { _ in completions.set("c"); done.signal() }
        #expect(fake.synced == ["a"])

        fake.releaseOne()
        #expect(done.wait(timeout: .now() + 5) == .success)
        fake.waitUntilStarted()
        #expect(fake.synced == ["a", "c"])

        fake.releaseOne()
        #expect(done.wait(timeout: .now() + 5) == .success)
        #expect(done.wait(timeout: .now() + 5) == .success)
        // Every caller hears back, including the one whose context was superseded.
        #expect(completions.count == 3)

        // The queue is idle again: a fresh context runs straight away.
        fake.stalls = false
        queue.enqueue(Self.context("d")) { _ in done.signal() }
        #expect(done.wait(timeout: .now() + 5) == .success)
        #expect(fake.synced == ["a", "c", "d"])
    }

    @Test func syncReportsSuccess() async {
        let fake = FakeContextSync()
        let queue = WatchContextSyncQueue(label: "test", perform: fake.perform)

        let error = await queue.sync(Self.context("a"), timeout: 5)

        #expect(error == nil)
        #expect(fake.synced == ["a"])
    }

    @Test func syncReportsTheUnderlyingError() async {
        let fake = FakeContextSync()
        fake.error = SyncFailed()
        let queue = WatchContextSyncQueue(label: "test", perform: fake.perform)

        let error = await queue.sync(Self.context("a"), timeout: 5)

        #expect(error is SyncFailed)
    }

    @Test func syncGivesUpWhileTheSessionIsStalled() async {
        let fake = FakeContextSync()
        fake.stalls = true
        let queue = WatchContextSyncQueue(label: "test", perform: fake.perform)

        let error = await queue.sync(Self.context("a"), timeout: 0.2)

        #expect(error is WatchContextSyncQueue.TimedOut)
        #expect(error?.localizedDescription.isEmpty == false)
        // The update is still in flight; its late completion must not resume the continuation twice,
        // and the queue must be usable once the session recovers.
        fake.stalls = false
        fake.releaseOne()
        let followUp = await queue.sync(Self.context("b"), timeout: 5)
        #expect(followUp == nil)
        #expect(fake.synced == ["a", "b"])
    }
}

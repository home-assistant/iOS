import Foundation

/// Mutual exclusion for tests that touch state every test in the process shares: the global
/// `Current` environment, `UserDefaults`, the app database, keychain-backed stores and singletons.
///
/// Swift Testing runs tests in parallel inside one process. `.serialized` only keeps the tests of
/// one suite apart from each other: two suites that both swap `Current.servers` still overlap, and
/// a `struct` without `@Suite` runs its tests concurrently with everything else. `.sharedState`
/// takes this lock around each test case so no two of them run at the same time, whatever suite
/// they belong to, while tests that leave shared state alone keep running in parallel.
///
/// Waiters are resumed in order, so a test never starves behind a stream of newcomers. A task that
/// already holds the lock (a nested suite, a helper taking it again) reenters instead of waiting on
/// itself. Work that leaves the task tree (`Task.detached`, a dispatch queue) does not inherit the
/// hold and would deadlock waiting for the test that spawned it; take the lock on the test, not in
/// what it spawns.
public actor SharedStateLock {
    public static let shared = SharedStateLock()

    @TaskLocal private static var isHeldByCurrentTask = false

    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public nonisolated func withLock<R: Sendable>(_ body: @Sendable () async throws -> R) async rethrows -> R {
        if Self.isHeldByCurrentTask {
            return try await body()
        }
        await acquire()
        do {
            let result = try await Self.$isHeldByCurrentTask.withValue(true) {
                try await body()
            }
            await release()
            return result
        } catch {
            await release()
            throw error
        }
    }

    private func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        if waiters.isEmpty {
            isHeld = false
        } else {
            // Hand the hold straight to the next waiter so a newcomer cannot slip in between.
            waiters.removeFirst().resume()
        }
    }
}

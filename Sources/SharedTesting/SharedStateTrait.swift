import Foundation
import Shared
import Testing

/// Runs each test case under ``SharedStateLock``, so it never overlaps another `.sharedState` test,
/// and puts back the members of `Current` it replaced (see ``CurrentSnapshot``) when it ends.
///
/// Apply it to every suite, or test, that assigns to `Current.*`, writes `UserDefaults`, the app
/// database or the keychain, or drives a singleton. It subsumes `.serialized`: the tests of the
/// suite run one at a time, and so do the `.sharedState` tests of every other suite. Tests that only
/// read shared state and never change it do not need it.
///
/// Prefer ``IsolatedEnvironmentTrait`` (`.isolatedEnvironment`) for new tests whose code under test
/// stays inside structured concurrency: it gives each test its own `Current` and keeps the test
/// parallel. `.sharedState` is for the code paths that still hop through dispatch queues or
/// PromiseKit, where a task-local override would not be seen.
public struct SharedStateTrait: SuiteTrait, TestTrait, TestScoping {
    public var isRecursive: Bool { true }

    public func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        try await SharedStateLock.shared.withLock {
            let start = ContinuousClock.now
            let snapshot = CurrentSnapshot()
            let signalsBefore = AppSensorSignalWatch.shared.signalCount(watching: Current.sensors)
            defer {
                snapshot.restore()
                Self.reportLongHold(of: test, since: start)
                Self.reportSensorSignals(of: test, since: signalsBefore)
            }
            try await function()
        }
    }

    /// A signal on the app's sensor container reaches every `HomeAssistantAPI` registered with it, and
    /// each answers with a full read of every sensor provider (several of them on the main thread)
    /// and a webhook to its fake server, which then fails and retries for the rest of the run. Names
    /// the test that sent it, so it can be given a container of its own.
    private static func reportSensorSignals(of test: Test, since signalsBefore: Int) {
        let signals = AppSensorSignalWatch.shared.signalCount() - signalsBefore
        guard signals > 0 else { return }
        print(
            "SharedStateTrait: \(test.id) signaled the app's sensor container \(signals) time(s); "
                + "give the test its own with `Current.sensors = SensorContainer()`"
        )
    }

    /// Every other `.sharedState` test waits while this one holds the lock, so a slow one stalls the
    /// whole run. Names the ones worth looking at in the test log.
    private static func reportLongHold(of test: Test, since start: ContinuousClock.Instant) {
        let held = ContinuousClock.now - start
        guard held > .seconds(5) else { return }
        print("SharedStateTrait: \(test.id) held the shared-state lock for \(held)")
    }
}

public extension Trait where Self == SharedStateTrait {
    /// Serializes the test with every other test that touches process-wide state.
    static var sharedState: Self { Self() }
}

/// Counts the update signals that reach the app's own `SensorContainer`, the one `Current.sensors`
/// holds when the first `.sharedState` test starts.
///
/// Switching a sensor on or off signals the container, and so does code that does it for the user
/// (kiosk mode, the sensor settings screens). In a test process the app's container is observed by
/// every API any earlier test left alive, so one such signal from a test costs minutes of main-thread
/// time: tests give themselves a container instead, and this is how one that doesn't is found.
final class AppSensorSignalWatch: SensorObserver, @unchecked Sendable {
    static let shared = AppSensorSignalWatch()

    private let lock = NSLock()
    private var signals = 0
    private var isWatching = false

    /// The signals seen so far, after starting to watch `container` if nothing is watched yet.
    func signalCount(watching container: SensorContainer? = nil) -> Int {
        lock.lock()
        let startWatching = container != nil && !isWatching
        if startWatching {
            isWatching = true
        }
        let count = signals
        lock.unlock()

        if startWatching, let container {
            container.register(observer: self)
        }
        return count
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {}

    func sensorContainer(
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason,
        lastUpdate: SensorObserverUpdate?
    ) {
        lock.lock()
        signals += 1
        lock.unlock()
    }
}

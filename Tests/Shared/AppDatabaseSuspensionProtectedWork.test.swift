import Foundation
import GRDB
import PromiseKit
@testable import Shared
import Testing

/// Serialized because every test swaps the global `Current.backgroundTask`.
@Suite("AppDatabaseSuspension protected work", .serialized)
struct AppDatabaseSuspensionProtectedWorkTests {
    /// Records the notifications posted by the instance under test.
    private final class Recorder {
        private let lock = NSLock()
        private var postedNames: [Notification.Name] = []

        var posted: [Notification.Name] {
            lock.lock()
            defer { lock.unlock() }
            return postedNames
        }

        func recordPost(_ name: Notification.Name) {
            lock.lock()
            postedNames.append(name)
            lock.unlock()
        }
    }

    /// Carries a value written on the protected-work queue back to the test thread.
    private final class Box<Value> {
        private let lock = NSLock()
        private var stored: Value?

        var value: Value? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return stored
            }
            set {
                lock.lock()
                stored = newValue
                lock.unlock()
            }
        }
    }

    /// Stands in for `UIApplication`/`ProcessInfo` background tasks. When `expires` is set it
    /// rejects the promise it hands back, which is how the real runner reports running out of
    /// background time.
    private final class FakeBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
        private let lock = NSLock()
        private var recordedNames: [String] = []
        private let expires: Bool

        init(expires: Bool = false) {
            self.expires = expires
        }

        var names: [String] {
            lock.lock()
            defer { lock.unlock() }
            return recordedNames
        }

        func callAsFunction<PromiseValue>(
            withName name: String,
            wrapping: (TimeInterval?) -> Promise<PromiseValue>
        ) -> Promise<PromiseValue> {
            lock.lock()
            recordedNames.append(name)
            lock.unlock()

            let wrapped = wrapping(nil)
            return expires ? Promise(error: BackgroundTaskError.outOfTime) : wrapped
        }
    }

    private func makeSuspension() -> (AppDatabaseSuspension, Recorder) {
        let recorder = Recorder()
        let suspension = AppDatabaseSuspension(
            performExpiringActivity: { _, _ in },
            postNotification: { recorder.recordPost($0) }
        )
        return (suspension, recorder)
    }

    /// The work runs asynchronously on a private queue, so every assertion about what it left
    /// behind has to wait for it rather than read straight after the call returns.
    private func waitUntil(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if condition() {
                return true
            }
            usleep(1000)
        }
        return condition()
    }

    private func withBackgroundTaskRunner<T>(
        _ runner: HomeAssistantBackgroundTaskRunner,
        _ body: () throws -> T
    ) rethrows -> T {
        let previous = Current.backgroundTask
        Current.backgroundTask = runner
        defer { Current.backgroundTask = previous }
        return try body()
    }

    @Test("Work runs off the caller's thread, on the protected-work queue")
    func workRunsOnItsOwnQueue() {
        let (suspension, _) = makeSuspension()
        let runner = FakeBackgroundTaskRunner()
        let label = Box<String>()

        withBackgroundTaskRunner(runner) {
            suspension.performProtectedWork(named: .panelsSave) {
                label.value = String(cString: __dispatch_queue_get_label(nil))
            }

            #expect(waitUntil { label.value != nil })
        }

        #expect(label.value == "io.robbie.HomeAssistant.database-protected-work")
    }

    @Test("The work is held by a background task named after the caller")
    func backgroundTaskIsNamedAfterTheCaller() {
        let (suspension, recorder) = makeSuspension()
        let runner = FakeBackgroundTaskRunner()

        withBackgroundTaskRunner(runner) {
            suspension.performProtectedWork(named: .appIconShortcutItems) {}
            #expect(waitUntil { recorder.posted.count >= 1 })
        }

        #expect(runner.names == [BackgroundTask.appIconShortcutItems.rawValue])
    }

    @Test("Work resumes the database and leaves it resumed when the app stayed foregrounded")
    func foregroundWorkLeavesDatabaseResumed() {
        let (suspension, recorder) = makeSuspension()
        let runner = FakeBackgroundTaskRunner()
        let finished = DispatchSemaphore(value: 0)

        withBackgroundTaskRunner(runner) {
            suspension.performProtectedWork(named: .panelsSave) {
                finished.signal()
            }
            #expect(finished.wait(timeout: .now() + 5) == .success)
            // Nothing asked for suspension, so the only notification is the resume that opened
            // the database for this work.
            #expect(waitUntil { recorder.posted == [Database.resumeNotification] })
        }

        #expect(recorder.posted == [Database.resumeNotification])
    }

    @Test("Backgrounding while the work runs hands the database back suspended")
    func backgroundingDuringWorkResuspends() {
        let (suspension, recorder) = makeSuspension()
        let runner = FakeBackgroundTaskRunner()

        withBackgroundTaskRunner(runner) {
            suspension.performProtectedWork(named: .panelsSave) {
                // What `LifecycleManager.didEnterBackground` does mid-write.
                suspension.suspend()
            }

            #expect(waitUntil { recorder.posted.last == Database.suspendNotification })
        }

        #expect(recorder.posted.first == Database.resumeNotification)
        #expect(recorder.posted.last == Database.suspendNotification)
    }

    @Test("Running out of background time suspends the database so the file lock is released")
    func expiringBackgroundTaskSuspends() {
        let (suspension, recorder) = makeSuspension()
        let runner = FakeBackgroundTaskRunner(expires: true)

        withBackgroundTaskRunner(runner) {
            suspension.performProtectedWork(named: .panelsSave) {}

            #expect(waitUntil { recorder.posted.last == Database.suspendNotification })
        }

        #expect(recorder.posted.contains(Database.suspendNotification))
    }
}

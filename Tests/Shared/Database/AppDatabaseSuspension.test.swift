import Foundation
import GRDB
@testable import Shared
import Testing

@Suite("AppDatabaseSuspension")
struct AppDatabaseSuspensionTests {
    /// Records the notifications posted and expiring-activity blocks armed by an instance under test.
    private final class Recorder {
        private let lock = NSLock()
        private var postedNames: [Notification.Name] = []
        private var activityBlocks: [(Bool) -> Void] = []

        var posted: [Notification.Name] {
            lock.lock()
            defer { lock.unlock() }
            return postedNames
        }

        var armedActivities: [(Bool) -> Void] {
            lock.lock()
            defer { lock.unlock() }
            return activityBlocks
        }

        func recordPost(_ name: Notification.Name) {
            lock.lock()
            postedNames.append(name)
            lock.unlock()
        }

        func recordActivity(_ block: @escaping (Bool) -> Void) {
            lock.lock()
            activityBlocks.append(block)
            lock.unlock()
        }
    }

    private func makeSuspension() -> (AppDatabaseSuspension, Recorder) {
        let recorder = Recorder()
        let suspension = AppDatabaseSuspension(
            performExpiringActivity: { _, block in recorder.recordActivity(block) },
            postNotification: { recorder.recordPost($0) }
        )
        return (suspension, recorder)
    }

    @Test("Foreground access resumes without arming an expiring activity")
    func foregroundAccessDoesNotArmActivity() {
        let (suspension, recorder) = makeSuspension()

        suspension.resumeForAccess()

        #expect(recorder.posted == [Database.resumeNotification])
        #expect(recorder.armedActivities.isEmpty)
    }

    @Test("Background access resumes under an expiring activity that re-suspends on expiry")
    func backgroundAccessArmsActivityAndExpiryResuspends() {
        let (suspension, recorder) = makeSuspension()

        suspension.suspend()
        #expect(recorder.posted == [Database.suspendNotification])

        suspension.resumeForAccess()
        #expect(recorder.posted == [Database.suspendNotification, Database.resumeNotification])
        #expect(recorder.armedActivities.count == 1)

        // Expiry re-suspends so nothing is caught holding the SQLite file lock (0xdead10cc).
        recorder.armedActivities[0](true)
        #expect(recorder.posted.last == Database.suspendNotification)

        // A later access re-arms a fresh activity.
        suspension.resumeForAccess()
        #expect(recorder.armedActivities.count == 2)
    }

    @Test("Repeated background accesses share a single expiring activity")
    func onlyOneActivityArmedAtATime() {
        let (suspension, recorder) = makeSuspension()

        suspension.suspend()
        suspension.resumeForAccess()
        suspension.resumeForAccess()

        #expect(recorder.armedActivities.count == 1)
    }

    @Test("Foreground resume releases the parked expiring activity")
    func resumeReleasesParkedActivity() throws {
        let (suspension, recorder) = makeSuspension()

        suspension.suspend()
        suspension.resumeForAccess()
        let block = try #require(recorder.armedActivities.first)

        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            // The non-expired invocation parks until foreground resume (or expiry).
            block(false)
            finished.signal()
        }

        suspension.resume()
        #expect(finished.wait(timeout: .now() + 5) == .success)
    }

    @Test("Suspension waits for the last in-flight protected access")
    func protectedAccessesAreRefcounted() {
        let (suspension, recorder) = makeSuspension()

        suspension.beginProtectedAccess()
        suspension.beginProtectedAccess()
        #expect(recorder.posted == [Database.resumeNotification, Database.resumeNotification])

        // The first access finishing must not suspend — the second is still writing, and suspending
        // aborts its statement mid-transaction ("SQLite error 4: Database is suspended").
        suspension.endProtectedAccess(suspend: true)
        #expect(recorder.posted.last == Database.resumeNotification)

        suspension.endProtectedAccess(suspend: true)
        #expect(recorder.posted.last == Database.suspendNotification)
    }

    @Test("An expiring activity does not suspend while another access is still running")
    func suspendIfIdleRespectsInFlightAccess() {
        let (suspension, recorder) = makeSuspension()

        suspension.beginProtectedAccess()
        suspension.suspendIfIdle()
        #expect(recorder.posted == [Database.resumeNotification])

        suspension.endProtectedAccess(suspend: true)
        #expect(recorder.posted.last == Database.suspendNotification)
    }

    @Test("An access that ends while foregrounded leaves the database resumed")
    func endProtectedAccessCanKeepDatabaseResumed() {
        let (suspension, recorder) = makeSuspension()

        suspension.beginProtectedAccess()
        suspension.endProtectedAccess(suspend: false)
        #expect(recorder.posted == [Database.resumeNotification])

        // The count still returned to zero, so a later idle check can suspend.
        suspension.suspendIfIdle()
        #expect(recorder.posted.last == Database.suspendNotification)
    }

    @Test("A stale expiration after foreground resume does not re-suspend")
    func staleExpirationDoesNotSuspend() throws {
        let (suspension, recorder) = makeSuspension()

        suspension.suspend()
        suspension.resumeForAccess()
        let block = try #require(recorder.armedActivities.first)

        suspension.resume()
        let postedBeforeExpiry = recorder.posted

        block(true)
        #expect(recorder.posted == postedBeforeExpiry)
    }
}

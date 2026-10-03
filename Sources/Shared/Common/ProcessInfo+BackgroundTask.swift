import Foundation
import PromiseKit

public class ProcessInfoBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
    public func callAsFunction<PromiseValue>(
        withName name: String,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        ProcessInfo.processInfo.backgroundTask(withName: name, wrapping: wrapping)
    }

    #if os(macOS)
    private static let inFlightLock = NSLock()
    private static var inFlightCount = 0

    /// How many background tasks are running right now.
    public static var inFlight: Int {
        inFlightLock.withLock { inFlightCount }
    }

    fileprivate static func adjustInFlight(by delta: Int) {
        inFlightLock.withLock { inFlightCount += delta }
    }

    /// Calls `completion` on the main thread once no background task is running, checked from `after`
    /// seconds on so work that is only just being queued is seen, or when `timeout` passes. Polled by a
    /// timer in the common run loop modes, which keep running while AppKit waits on a termination reply.
    public static func whenIdle(after: TimeInterval, timeout: TimeInterval, completion: @escaping () -> Void) {
        let start = Date()
        let timer = Timer(timeInterval: 0.1, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(start)
            guard elapsed >= timeout || (elapsed >= after && inFlight == 0) else { return }
            timer.invalidate()
            completion()
        }
        RunLoop.main.add(timer, forMode: .common)
    }
    #endif
}

private extension ProcessInfo {
    func backgroundTask<PromiseValue>(
        withName name: String,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        #if os(macOS)
        // A Mac app is not suspended when it leaves the screen, so there is no deadline to race; the
        // activity only keeps the system from terminating or napping the app while the work runs.
        return HomeAssistantBackgroundTask.execute(
            withName: name,
            beginBackgroundTask: { name, _ -> (NSObjectProtocol?, TimeInterval?) in
                let activity = beginActivity(
                    options: [.automaticTerminationDisabled, .suddenTerminationDisabled, .background],
                    reason: name
                )
                ProcessInfoBackgroundTaskRunner.adjustInFlight(by: 1)
                return (activity, nil)
            }, endBackgroundTask: { [self] activity in
                ProcessInfoBackgroundTaskRunner.adjustInFlight(by: -1)
                endActivity(activity)
            }, wrapping: wrapping
        )
        #else
        let identifier = UUID()
        let semaphore = DispatchSemaphore(value: 0)

        return HomeAssistantBackgroundTask.execute(
            withName: name,
            beginBackgroundTask: { name, expirationHandler -> (UUID?, TimeInterval?) in
                performExpiringActivity(withReason: name) { expire in
                    if expire {
                        expirationHandler()
                    } else {
                        semaphore.wait()
                    }
                }
                return (identifier, nil)
            }, endBackgroundTask: { _ in
                semaphore.signal()
            }, wrapping: wrapping
        )
        #endif
    }
}

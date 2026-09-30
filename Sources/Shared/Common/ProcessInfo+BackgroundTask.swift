import Foundation
import PromiseKit

public class ProcessInfoBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
    public func callAsFunction<PromiseValue>(
        withName name: String,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        ProcessInfo.processInfo.backgroundTask(withName: name, wrapping: wrapping)
    }
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
                return (activity, nil)
            }, endBackgroundTask: { [self] activity in
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

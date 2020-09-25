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
    }
}

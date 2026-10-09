import Foundation
import PromiseKit

public class ProcessInfoBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
    public func callAsFunction<PromiseValue>(
        withName name: String,
        requiringAssertion: Bool,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        ProcessInfo.processInfo.backgroundTask(
            withName: name,
            requiringAssertion: requiringAssertion,
            wrapping: wrapping
        )
    }
}

private extension ProcessInfo {
    func backgroundTask<PromiseValue>(
        withName name: String,
        requiringAssertion: Bool,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        let identifier = UUID()
        let semaphore = DispatchSemaphore(value: 0)

        return HomeAssistantBackgroundTask.execute(
            withName: name,
            beginBackgroundTask: { name, expirationHandler -> (UUID?, TimeInterval?) in
                let lock = NSLock()
                var wasGranted: Bool?
                let answered = DispatchSemaphore(value: 0)

                performExpiringActivity(withReason: name) { expire in
                    lock.lock()
                    let isFirstAnswer = wasGranted == nil
                    if isFirstAnswer {
                        wasGranted = !expire
                    }
                    lock.unlock()
                    if isFirstAnswer {
                        answered.signal()
                    }

                    if expire {
                        expirationHandler()
                    } else {
                        semaphore.wait()
                    }
                }

                guard requiringAssertion else { return (identifier, nil) }

                // A refusal only arrives through the callback, so wait for its first answer.
                let didAnswer = answered.wait(timeout: .now() + 1) == .success
                lock.lock()
                if !didAnswer {
                    wasGranted = false
                }
                let isGranted = wasGranted == true
                lock.unlock()

                guard isGranted else {
                    // Lets a grant that arrives after giving up return straight away.
                    semaphore.signal()
                    return (nil, nil)
                }
                return (identifier, nil)
            }, endBackgroundTask: { _ in
                semaphore.signal()
            }, requiresAssertion: requiringAssertion,
            wrapping: wrapping
        )
    }
}

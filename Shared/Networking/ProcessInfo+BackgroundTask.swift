import Foundation
import PromiseKit

extension ProcessInfo {
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
                        Current.Log.info("expiring \(identifier) [\(name)]")
                        expirationHandler()
                    } else {
                        Current.Log.info("start blocking \(identifier) [\(name)]")
                        semaphore.wait()
                        Current.Log.info("end blocking \(identifier) [\(name)]")
                    }
                }
                return (identifier, nil)
            }, endBackgroundTask: { identifier in
                Current.Log.info("signaling \(identifier) [\(name)]")
                semaphore.signal()
            }, wrapping: wrapping
        )
    }
}

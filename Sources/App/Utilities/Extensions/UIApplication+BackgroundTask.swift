import Foundation
import PromiseKit
import Shared
import UIKit

class ApplicationBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
    public func callAsFunction<PromiseValue>(
        withName name: String,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        UIApplication.shared.backgroundTask(withName: name, wrapping: wrapping)
    }
}

private extension UIApplication {
    func backgroundTask<PromiseValue>(
        withName name: String,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        HomeAssistantBackgroundTask.execute(
            withName: name,
            beginBackgroundTask: { name, expirationHandler in
                let identifier = beginBackgroundTask(withName: name, expirationHandler: expirationHandler)
                let remaining: TimeInterval? = {
                    if Thread.isMainThread {
                        let timeRemaining = self.backgroundTimeRemaining
                        return timeRemaining < 100 ? timeRemaining : nil
                    } else {
                        var result: TimeInterval?
                        DispatchQueue.main.sync {
                            let timeRemaining = self.backgroundTimeRemaining
                            result = timeRemaining < 100 ? timeRemaining : nil
                        }
                        return result
                    }
                }()
                return (identifier == .invalid ? nil : identifier, remaining)
            }, endBackgroundTask: { identifier in
                self.endBackgroundTask(identifier)
            }, wrapping: wrapping
        )
    }
}

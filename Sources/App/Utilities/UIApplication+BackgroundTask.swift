import Foundation
import UIKit
import PromiseKit
import Shared

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
                let remaining = backgroundTimeRemaining < 100 ? backgroundTimeRemaining : nil

                Current.Log.info {
                    if let remaining = remaining {
                        return "background time remaining \(remaining)"
                    } else {
                        return "background time remaining could not be determined"
                    }
                }

                return (identifier == .invalid ? nil : identifier, remaining)
            }, endBackgroundTask: { identifier in
                self.endBackgroundTask(identifier)
            }, wrapping: wrapping
        )
    }
}

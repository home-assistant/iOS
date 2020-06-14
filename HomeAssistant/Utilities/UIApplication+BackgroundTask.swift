import Foundation
import UIKit
import PromiseKit
import Shared

extension UIApplication {
    func backgroundTask<PromiseValue>(
        withName name: String,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        HomeAssistantBackgroundTask.execute(
            withName: name,
            beginBackgroundTask: { name, expirationHandler in
                let identifier = self.beginBackgroundTask(withName: name, expirationHandler: expirationHandler)
                let remaining = self.backgroundTimeRemaining < 100 ? self.backgroundTimeRemaining : nil

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

import Foundation
import UIKit
import PromiseKit
import Shared

extension UIApplication {
    func backgroundTask<T>(withName name: String, wrapping: () -> Promise<T>) -> Promise<T> {
        HomeAssistantBackgroundTask.execute(
            withName: name,
            beginBackgroundTask: { name, expirationHandler in
                let identifier = self.beginBackgroundTask(withName: name, expirationHandler: expirationHandler)
                return identifier == .invalid ? nil : identifier
            }, endBackgroundTask: { identifier in
                self.endBackgroundTask(identifier)
            }, wrapping: wrapping
        )
    }
}

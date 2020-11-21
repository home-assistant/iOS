import Foundation
import NetworkExtension
import UserNotifications

class PushProvider: NEAppPushProvider {
    override func start(completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
}

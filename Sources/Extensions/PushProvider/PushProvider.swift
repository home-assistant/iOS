import Foundation
import NetworkExtension
import UserNotifications

@objc class PushProvider: NEAppPushProvider {
    override func start(completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
}


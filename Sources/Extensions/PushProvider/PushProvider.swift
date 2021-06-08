import Foundation
import NetworkExtension
import UserNotifications

@objc class PushProvider: NEAppPushProvider {
    override func start(completionHandler: @escaping (Error?) -> Void) {
        _ = observe(\.providerConfiguration) { [weak self] _, _ in
            print("configuration: \(self?.providerConfiguration)")
        }

        print("hey *** pushprovider *** hey")
        completionHandler(nil)
    }

    override func handleTimerEvent() {
        print("hi")
    }
}


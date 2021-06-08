import Foundation
import NetworkExtension
import UserNotifications
import Shared

@objc class PushProvider: NEAppPushProvider, LocalPushManagerDelegate {
    private var localPushManager: LocalPushManager?

    override func start(completionHandler: @escaping (Error?) -> Void) {
        localPushManager = with(LocalPushManager()) {
            $0.delegate = self
        }

        Current.apiConnection.send(.init(type: .ping, data: [:])).promise
            .done { _ in
                completionHandler(nil)
            }
            .catch { error in
                // TODO: also error for state transitioning to error before this is completed
                completionHandler(error)
            }

        _ = observe(\.providerConfiguration) { [weak self] _, _ in
            print("configuration: \(self?.providerConfiguration)")
        }

        print("hey *** pushprovider *** hey")
        completionHandler(nil)
    }

    override func handleTimerEvent() {
        print("hi")
    }

    func localPushManager(_ manager: LocalPushManager, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
    }
}


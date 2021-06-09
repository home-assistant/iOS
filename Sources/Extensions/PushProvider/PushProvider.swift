import Foundation
import NetworkExtension
import HAKit
import UserNotifications
import Shared
import PromiseKit

@objc class PushProvider: NEAppPushProvider, LocalPushManagerDelegate {
    private var localPushManager: LocalPushManager?

    override func start(completionHandler: @escaping (Error?) -> Void) {
        Current.Log.notify("starting", log: true)

        localPushManager = with(LocalPushManager()) {
            $0.delegate = self
        }

        Current.apiConnection.connect()

        // state of the connection dictates our callback to the completion handler
        // this wraps it in a way that guarantees we only ever call it once (via the promise's guarantee of that)
        firstly { () -> Promise<Void> in
            let (promise, seal) = Promise<Void>.pending()

            func checkState() {
                switch Current.apiConnection.state {
                case .ready(version: _):
                    seal.fulfill(())
                case let .disconnected(reason: .waitingToReconnect(lastError: .some(error), atLatest: _, retryCount: _)):
                    seal.reject(error)
                case .authenticating,
                     .connecting,
                     .disconnected(reason: .disconnected),
                     .disconnected(reason: .waitingToReconnect(lastError: .none, atLatest: _, retryCount: _)):
                    break
                }
            }

            let token = NotificationCenter.default.addObserver(
                forName: HAConnectionState.didTransitionToStateNotification,
                object: Current.apiConnection,
                queue: nil
            ) { _ in
                checkState()
            }

            checkState()

            return promise
                .ensure { NotificationCenter.default.removeObserver(token) }
        }.done {
            Current.Log.notify("reporting we connected", log: true)
            completionHandler(nil)
        }.catch { error in
            Current.Log.notify("reporting we errored", log: true)
            completionHandler(error)
        }
    }

    override func stop(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Current.Log.notify("stopping with reason \(reason)", log: true)
        localPushManager = nil
    }

    override func handleTimerEvent() {
        // we may be signaled that it's a good time to connect, so do so
        Current.apiConnection.connect()
    }

    func localPushManager(_ manager: LocalPushManager, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        // todo: ugh
    }
}


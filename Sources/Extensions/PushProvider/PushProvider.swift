import Foundation
import NetworkExtension
import HAKit
import UserNotifications
import Shared
import PromiseKit

@objc class PushProvider: NEAppPushProvider, LocalPushManagerDelegate {
    private var localPushManager: LocalPushManager?
    private let commandManager = NotificationCommandManager()

    private var stateObserver: NSObjectProtocol? {
        willSet {
            if let stateObserver = stateObserver, stateObserver !== newValue {
                NotificationCenter.default.removeObserver(stateObserver)
            }
        }
    }

    override init() {
        super.init()
        Current.Log.notify("initialized", log: .info)
    }

    deinit {
        if let stateObserver = stateObserver {
            NotificationCenter.default.removeObserver(stateObserver)
        }
    }

    override func start(completionHandler: @escaping (Error?) -> Void) {
        Current.Log.notify("starting", log: .info)

        guard let settingsKey = providerConfiguration?[LocalPushStateSync.settingsKey] as? String else {
            Current.Log.notify("aborting due to missing settings key", log: .error)
            stop(with: .configurationFailed, completionHandler: {
                Current.Log.notify("finished failing due to no settings key", log: .info)
            })
            return
        }

        let localPushManager = with(LocalPushManager()) {
            $0.delegate = self
        }
        self.localPushManager = localPushManager

        let valueSync = LocalPushStateSync(settingsKey: settingsKey)
        valueSync.value = localPushManager.state
        stateObserver = NotificationCenter.default.addObserver(
            forName: LocalPushManager.stateDidChange,
            object: localPushManager,
            queue: nil
        ) { [localPushManager] _ in
            valueSync.value = localPushManager.state
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
            Current.Log.notify("reporting we connected", log: .info)
            completionHandler(nil)
        }.catch { error in
            Current.Log.notify("reporting we errored", log: .info)
            completionHandler(error)
        }
    }

    override func stop(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Current.Log.notify("stopping with reason \(reason)", log: .error)
        localPushManager = nil
    }

    override func handleTimerEvent() {
        // we may be signaled that it's a good time to connect, so do so
        Current.apiConnection.connect()
    }

    func localPushManager(_ manager: LocalPushManager, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        commandManager.handle(userInfo).done {
            Current.Log.notify("handled command: \(userInfo)", log: .info)
        }.catch { error in
            Current.Log.notify("failed: \(error)", log: .info)
        }
    }
}


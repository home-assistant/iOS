import Foundation
import HAKit
import NetworkExtension
import PromiseKit
import Shared
import UserNotifications

@objc class PushProvider: NEAppPushProvider, LocalPushManagerDelegate {
    private let commandManager = NotificationCommandManager()
    private let periodicUpdateManager = PeriodicUpdateManager(applicationStateGetter: { .background })

    enum PushProviderError: Error {
        case noSuchServer
        case noConfiguration
    }

    private var localPushManagers = [LocalPushManager]()
    private var stateObservers = [NSObjectProtocol]() {
        willSet {
            for observer in stateObservers where !newValue.contains(where: { $0 === observer }) {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    override init() {
        super.init()
        Current.Log.notify("initialized", log: .info)
    }

    deinit {
        stateObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func start(completionHandler: @escaping (Error?) -> Void) {
        Current.Log.notify("starting", log: .info)

        periodicUpdateManager.connectAPI(reason: .background)

        // promise prevents our firing the completion handler more than once
        let (didStartPromise, didStartSeal) = Promise<Void>.pending()
        didStartPromise.done {
            completionHandler(nil)
        }.catch { error in
            completionHandler(error)
        }

        stateObservers.append(observe(\.providerConfiguration, options: .initial) { pushProvider, _ in
            guard let config = pushProvider.providerConfiguration,
                  let data = config[PushProviderConfiguration.providerConfigurationKey] as? Data else {
                didStartSeal.reject(PushProviderError.noConfiguration)
                return
            }

            do {
                let decoder = JSONDecoder()
                let providers = try decoder.decode([PushProviderConfiguration].self, from: data)

                when(fulfilled: providers.map(pushProvider.localPushManager(for:))).done { newManagers in
                    Current.Log.notify("started push managers: \(newManagers.count)", log: .info)
                    pushProvider.localPushManagers = newManagers
                    didStartSeal.fulfill(())
                }.catch { error in
                    didStartSeal.reject(error)
                }
            } catch {
                Current.Log.notify("failed to compose from settings: \(error)", log: .error)
                didStartSeal.reject(error)
            }
        })
    }

    override func stop(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Current.Log.notify("stopping with reason \(reason)", log: .error)

        stateObservers.removeAll()
        periodicUpdateManager.invalidatePeriodicUpdateTimer()

        for manager in localPushManagers {
            manager.invalidate()
            Current.api(for: manager.server).connection.disconnect()
        }

        localPushManagers.removeAll()
        completionHandler()
    }

    override func handleTimerEvent() {
        // we may be signaled that it's a good time to connect, so do so
        for manager in localPushManagers {
            Current.api(for: manager.server).connection.connect()
        }
    }

    private func localPushManager(for configuration: PushProviderConfiguration) -> Promise<LocalPushManager> {
        guard let server = Current.servers.server(for: configuration.serverIdentifier) else {
            return .init(error: PushProviderError.noSuchServer)
        }

        let localPushManager = with(LocalPushManager(server: server)) {
            $0.delegate = self
        }

        let valueSync = LocalPushStateSync(settingsKey: configuration.settingsKey)
        valueSync.value = localPushManager.state
        stateObservers.append(NotificationCenter.default.addObserver(
            forName: LocalPushManager.stateDidChange,
            object: localPushManager,
            queue: nil
        ) { [localPushManager] _ in
            valueSync.value = localPushManager.state
        })

        let connection = Current.api(for: server).connection

        // state of the connection dictates our callback to the completion handler
        // this wraps it in a way that guarantees we only ever call it once (via the promise's guarantee of that)
        return firstly { () -> Promise<Void> in
            let (promise, seal) = Promise<Void>.pending()

            func checkState() {
                switch connection.state {
                case .ready(version: _):
                    seal.fulfill(())
                case let .disconnected(reason: .waitingToReconnect(
                    lastError: .some(error),
                    atLatest: _,
                    retryCount: _
                )):
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
                object: connection,
                queue: nil
            ) { _ in
                checkState()
            }

            checkState()

            return promise
                .ensure { NotificationCenter.default.removeObserver(token) }
        }.tap { result in
            switch result {
            case .fulfilled:
                Current.Log.notify("reporting we connected", log: .info)
            case let .rejected(error):
                Current.Log.notify("reporting we errored with \(error)", log: .info)
            }
        }.map {
            localPushManager
        }
    }

    func localPushManager(_ manager: LocalPushManager, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        commandManager.handle(userInfo).done {
            Current.Log.notify("handled command: \(userInfo)", log: .info)
        }.catch { error in
            Current.Log.notify("failed: \(error)", log: .info)
        }
    }
}

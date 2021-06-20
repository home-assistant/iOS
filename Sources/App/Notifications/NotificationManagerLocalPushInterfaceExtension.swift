import Foundation
import NetworkExtension
import Shared
import PromiseKit
import HAKit

@available(iOS 14, *)
final class NotificationManagerLocalPushInterfaceExtension: NSObject, NotificationManagerLocalPushInterface, NEAppPushDelegate {
    var status: NotificationManagerLocalPushStatus {
        if let manager = manager, let value = stateSync.value {
            return .allowed(value)
        } else {
            return .inactive
        }
    }

    func addObserver(_ handler: @escaping (NotificationManagerLocalPushStatus) -> Void) -> HACancellable {
        let identifier = UUID()
        observers.append((identifier: identifier, handler: handler))
        return HABlockCancellable { [weak self] in
            self?.observers.removeAll(where: { $0.identifier == identifier })
        }
    }

    private var observers = [(identifier: UUID, handler: (NotificationManagerLocalPushStatus) -> Void)]()
    private func notifyObservers() {
        let status = status
        for observer in observers {
            observer.handler(status)
        }
    }

    static let settingsKey = "LocalPush:Main"
    private let stateSync = LocalPushStateSync(settingsKey: NotificationManagerLocalPushInterfaceExtension.settingsKey)
    
    private var tokens: [NSKeyValueObservation] = []
    private var manager: NEAppPushManager? {
        didSet {
            if manager !== oldValue {
                tokens.forEach { $0.invalidate() }
                if let manager = manager {
                    tokens = setupObservation(manager: manager)
                } else {
                    tokens = []
                }
                notifyObservers()
            }
        }
    }

    override init() {
        super.init()

        _ = stateSync.observe { [weak self] (state: LocalPushManager.State) in
            self?.notifyObservers()
        }

        // future multi-server: move this to container
        NEAppPushManager.loadAllFromPreferences { [self] managers, error in
            if let manager = managers?.first {
                configureManager(manager: manager)
            } else {
                if let error = error {
                    Current.Log.error("failed to load local push details: \(error)")
                }
                updateManager().cauterize()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(connectionInfoDidChange(_:)),
            name: SettingsStore.connectionInfoDidChange,
            object: nil
        )
    }

    @objc private func connectionInfoDidChange(_ note: Notification) {
        updateManager().cauterize()
    }

    private func configureManager(manager: NEAppPushManager) {
        self.manager = manager
        manager.delegate = self
    }

    private func setupObservation(manager: NEAppPushManager) -> [NSKeyValueObservation] {
        [
            manager.observe(\.isActive) { [weak self] manager, _ in
                Current.Log.info("manager is active: \(manager.isActive)")
                self?.notifyObservers()
            },
        ]
    }

    private func updateManager() -> Promise<Void> {
        guard
            let connectionInfo = Current.settingsStore.connectionInfo,
            connectionInfo.internalSSIDs?.isEmpty == false,
            connectionInfo.internalURL != nil,
            connectionInfo.isLocalPushEnabled
        else {
            return Promise { seal in
                guard let manager = self.manager else {
                    Current.Log.info("no local push - no internal info or not enabled")
                    seal.fulfill(())
                    return
                }

                Current.Log.info("removing manager \(manager) due to no internal info or not enabled")
                manager.removeFromPreferences { error in
                    Current.Log.info("remove from preferences: \(String(describing: error))")
                    seal.resolve(error)
                }
                self.manager = nil
            }
        }

        let manager: NEAppPushManager

        if let currentManager = self.manager {
            manager = currentManager
        } else {
            manager = NEAppPushManager()
            configureManager(manager: manager)
        }

        // just toggling isEnabled doesn't seem to kill off the extension reliably
        manager.isEnabled = true

        manager.localizedDescription = "HomeAssistant"
        manager.providerBundleIdentifier = Constants.BundleID + ".PushProvider"
        manager.matchSSIDs = Current.settingsStore.connectionInfo?.internalSSIDs ?? []
        manager.providerConfiguration = [
            LocalPushStateSync.settingsKey: Self.settingsKey
        ]

        return Promise { seal in
            manager.saveToPreferences { error in
                Current.Log.info("manager \(manager) updated, error: \(String(describing: error))")
                seal.resolve(error)
            }
        }
    }

    func appPushManager(
        _ manager: NEAppPushManager,
        didReceiveIncomingCallWithUserInfo userInfo: [AnyHashable: Any] = [:]
    ) {
        // we do not have calls
    }
}
